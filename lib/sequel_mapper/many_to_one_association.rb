require "sequel_mapper/dataset"

module SequelMapper
  class ManyToOneAssociation
    def initialize(mapping_name:, foreign_key:, key:, proxy_factory:)
      @mapping_name = mapping_name
      @foreign_key = foreign_key
      @key = key
      @proxy_factory = proxy_factory
    end

    def mapping_names
      [mapping_name]
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

    def eager_superset((superset), (associated_dataset))
      [
        Dataset.new(
          superset.where(key => associated_dataset.select(foreign_key)).to_a
        )
      ]
    end

    def build_query((superset), record)
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
    alias_method :delete, :dump

    private

    def foreign_key_value(record)
      record.fetch(foreign_key)
    end
  end
end
