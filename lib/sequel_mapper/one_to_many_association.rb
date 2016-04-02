require "sequel_mapper/dataset"

module Terrestrial
  class OneToManyAssociation
    def initialize(mapping_name:, foreign_key:, key:, order:, proxy_factory:)
      @mapping_name = mapping_name
      @foreign_key = foreign_key
      @key = key
      @order = order
      @proxy_factory = proxy_factory
    end

    def mapping_names
      [mapping_name]
    end
    attr_reader :mapping_name

    attr_reader :foreign_key, :key, :order, :proxy_factory
    private     :foreign_key, :key, :order, :proxy_factory

    def build_proxy(data_superset:, loader:, record:)
     proxy_factory.call(
        query: build_query(data_superset, record),
        loader: loader,
        mapping_name: mapping_name,
      )
    end

    def dump(parent_record, collection, depth, &block)
      foreign_key_pair = {
        foreign_key => parent_record.fetch(key),
      }

      collection.flat_map { |associated_object|
        block.call(mapping_name, associated_object, foreign_key_pair, depth + depth_modifier)
      }
    end
    alias_method :delete, :dump

    def extract_foreign_key(_record)
      {}
    end

    def eager_superset((superset), (associated_dataset))
      [
        Dataset.new(
          superset.where(
            foreign_key => associated_dataset.select(key)
          ).to_a
        )
      ]
    end

    def build_query((superset), record)
      order.apply(
        superset.where(foreign_key => record.fetch(key))
      )
    end

    private

    def depth_modifier
      +1
    end
  end
end
