module SequelMapper
  class ManyToManyAssociation
    def initialize(mapping_name:, foreign_key:, key:, proxy_factory:, association_foreign_key:, association_key:, through_namespace:, through_dataset:)
      @mapping_name = mapping_name
      @foreign_key = foreign_key
      @key = key
      @proxy_factory = proxy_factory
      @association_foreign_key = association_foreign_key
      @association_key = association_key
      # TODO: mapping name not namespace!
      @through_mapping_name = @through_namespace = through_namespace
      @through_dataset = through_dataset
    end

    attr_reader :mapping_name, :through_mapping_name

    attr_reader :foreign_key, :key, :proxy_factory, :association_key, :association_foreign_key, :through_namespace, :through_dataset
    private     :foreign_key, :key, :proxy_factory, :association_key, :association_foreign_key, :through_namespace, :through_dataset

    def build_proxy(data_superset:, loader:, record:)
     proxy_factory.call(
        query: build_query(data_superset, record),
        loader: ->(record_list) {
          record = record_list.first
          join_records = record_list.last

          loader.call(record, join_records)
        },
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

    def build_query(superset, parent_record)
      superset.where(
        association_key => through_dataset
          .select(association_foreign_key)
          .where(foreign_key => foreign_key_value(parent_record))
      )
      .lazy.map { |record|
        [record, [foreign_keys(parent_record, record)]]
      }
    end

    def dump(parent_record, collection, &block)
      flat_list_of_records_and_join_records(parent_record, collection, &block)
    end

    def delete(parent_record, collection, &block)
      flat_list_of_just_join_records(parent_record, collection, &block)
    end

    private

    def flat_list_of_records_and_join_records(parent_record, collection, &block)
      record_join_record_pairs(parent_record, collection, &block).flatten(1)
    end

    def flat_list_of_just_join_records(parent_record, collection, &block)
      record_join_record_pairs(parent_record, collection, &block)
        .map { |(_records, join_records)| join_records }
        .flatten(1)
    end

    def record_join_record_pairs(parent_record, collection, &block)
      (collection || []).map { |associated_object|
        records = block.call(mapping_name, associated_object, _no_foreign_key = {})

        join_records = records.take(1).flat_map { |record|
          fks = foreign_keys(parent_record, record)
          block.call(through_namespace, fks, fks)
        }

        records + join_records
      }
    end

    def foreign_keys(parent_record, record)
      {
        foreign_key => foreign_key_value(parent_record),
        association_foreign_key => record.fetch(association_key),
      }
    end

    def foreign_key_value(record)
      record.fetch(key)
    end
  end
end
