class LoadableOneToManyAssociation
  def initialize(mapping_name:, foreign_key:, key:, proxy_factory:)
    @mapping_name = mapping_name
    @foreign_key = foreign_key
    @key = key
    @proxy_factory = proxy_factory
  end

  attr_reader :mapping_name

  attr_reader :foreign_key, :key, :proxy_factory
  private     :foreign_key, :key, :proxy_factory

  def build_proxy(data_superset:, loader:, record:)
   proxy_factory.call(
      query: build_query(data_superset, record),
      loader: loader,
      mapper: nil,
    )
  end

  def dump(parent_record, collection, &block)
    foreign_key_pair = {
      foreign_key => parent_record.fetch(key),
    }

    collection.flat_map { |associated_object|
      block.call(mapping_name, associated_object, foreign_key_pair)
    }
  end

  def eager_superset(superset, associated_dataset)
    superset.where(foreign_key => associated_dataset.select(key))
  end

  def build_query(superset, record)
    superset.where(foreign_key => record.fetch(key))
  end
end

class LoadableManyToOneAssociation < LoadableOneToManyAssociation
  def initialize(mapping_name:, foreign_key:, key:, proxy_factory:)
    @mapping_name = mapping_name
    @foreign_key = foreign_key
    @key = key
    @proxy_factory = proxy_factory
  end

  attr_reader :mapping_name

  attr_reader :foreign_key, :key, :proxy_factory
  private     :foreign_key, :key, :proxy_factory

  def build_proxy(data_superset:, loader:, record:)
    proxy_factory.call(
      query: build_query(data_superset, record),
      loader: loader,
      preloaded_data: {
        key => foreign_key_value(record),
      },
    )
  end

  def eager_superset(superset, associated_dataset)
    superset.where(key => associated_dataset.select(foreign_key))
  end

  def build_query(superset, record)
    superset.where(key => foreign_key_value(record))
  end

  def dump(parent_record, collection, &block)
    collection.flat_map { |object|
      block.call(mapping_name, object, _foreign_key_does_not_go_here = {})
        .flat_map { |associated_record|

          foreign_key_pair = {
            foreign_key => associated_record.fetch(key),
          }

          [
            associated_record,
            parent_record.merge(foreign_key_pair),
          ]
        }
    }
  end

  private

  def foreign_key_value(record)
    record.fetch(foreign_key)
  end
end

class LoadableManyToManyAssociation < LoadableOneToManyAssociation
  def initialize(mapping_name:, foreign_key:, key:, proxy_factory:, association_foreign_key:, association_key:, through_namespace:, through_dataset:)
    @mapping_name = mapping_name
    @foreign_key = foreign_key
    @key = key
    @proxy_factory = proxy_factory
    @association_foreign_key = association_foreign_key
    @association_key = association_key
    @through_namespace = through_namespace
    @through_dataset = through_dataset
  end

  attr_reader :mapping_name

  attr_reader :foreign_key, :key, :proxy_factory, :association_key, :association_foreign_key, :through_namespace, :through_dataset
  private     :foreign_key, :key, :proxy_factory, :association_key, :association_foreign_key, :through_namespace, :through_dataset

  def build_proxy(data_superset:, loader:, record:)
   proxy_factory.call(
      query: build_query(data_superset, record),
      loader: loader,
      mapper: nil,
    )
  end

  def eager_superset(superset, associated_dataset)
    superset.where(
      association_key => through_dataset
        .select(association_foreign_key)
        .where(foreign_key => associated_dataset.select(key))
    )
  end

  def build_query(superset, record)
    superset.where(
      association_key => through_dataset
        .select(association_foreign_key)
        .where(foreign_key => foreign_key_value(record))
    )
  end

  def dump(parent_record, collection, &block)
    (collection || []).flat_map { |associated_object|
      block
        .call(mapping_name, associated_object, _foreign_key_does_not_go_here = {})
        .flat_map { |record|
          [
            record,
            SequelMapper::NamespacedRecord.new(
              through_namespace,
              {
                foreign_key => parent_record.fetch(key),
                association_foreign_key => record.fetch(association_key, nil),
                # TODO: Record association key is missing when record is from
                # the through dataset
              },
            )
          ]
        }
    }.flatten(1)
  end

  private

  def foreign_key_value(record)
    record.fetch(key)
  end
end
