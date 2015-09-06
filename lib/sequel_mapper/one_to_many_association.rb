require "sequel_mapper/dataset"

module SequelMapper
  class OneToManyAssociation
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
    alias_method :delete, :dump

    def eager_superset(superset, associated_dataset)
      Dataset.new(
        superset.where(
          foreign_key => associated_dataset.select(key)
        ).to_a
      )
    end

    def build_query(superset, record)
      superset.where(foreign_key => record.fetch(key))
    end
  end
end
