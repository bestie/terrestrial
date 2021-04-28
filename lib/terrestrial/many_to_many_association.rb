require "forwardable"
require "terrestrial/dataset"

module Terrestrial
  class ManyToManyAssociation
    def initialize(mapping_name:, join_mapping_name:, join_dataset:, foreign_key:, key:, proxy_factory:, association_foreign_key:, association_key:, order:)
      @mapping_name = mapping_name
      @join_mapping_name = join_mapping_name
      @join_dataset = join_dataset
      @foreign_key = foreign_key
      @key = key
      @proxy_factory = proxy_factory
      @association_foreign_key = association_foreign_key
      @association_key = association_key
      @order = order
    end

    def mapping_names
      [mapping_name, join_mapping_name]
    end

    def outgoing_foreign_keys
      []
    end

    def local_foreign_keys
      []
    end

    attr_reader :mapping_name, :join_mapping_name

    attr_reader :join_dataset, :foreign_key, :key, :proxy_factory, :association_key, :association_foreign_key, :order
    private     :join_dataset, :foreign_key, :key, :proxy_factory, :association_key, :association_foreign_key, :order

    def build_proxy(data_superset:, loader:, record:)
      proxy_factory.call(
        query: build_query(data_superset, record),
        loader: ->(record_list) {
          record = record_list.first
          join_records = record_list.last

          loader.call(record, join_records)
        },
        mapping_name: mapping_name,
      )
    end

    def eager_superset((superset, join_superset), (associated_dataset))
      subselect_data = Dataset.new(
        join_superset
          .where(foreign_key => associated_dataset.select(association_key))
          .to_a
      )

      eager_superset = Dataset.new(
        superset.where(key => subselect_data.select(association_foreign_key)).to_a
      )

      [
        eager_superset,
        subselect_data,
      ]
    end

    def build_query((superset, join_superset), parent_record)
      subselect_ids = join_superset
        .where(foreign_key => foreign_key_value(parent_record))
        .select(association_foreign_key)

      order
        .apply(superset.where(key => subselect_ids))
        .lazy
        .map { |record| [record, [foreign_keys(parent_record, record)]] }
    end

    def dump(parent_record, collection, depth, &block)
      flat_list_of_records_and_join_records(parent_record, collection, depth, &block)
    end

    def extract_foreign_key(_record)
      {}
    end

    def delete(parent_record, collection, depth, &block)
      flat_list_of_just_join_records(parent_record, collection, depth, &block)
    end

    private

    def flat_list_of_records_and_join_records(parent_record, collection, depth, &block)
      record_join_record_pairs(parent_record, collection, depth, &block).flatten(1)
    end

    def flat_list_of_just_join_records(parent_record, collection, depth, &block)
      record_join_record_pairs(parent_record, collection, depth, &block)
        .map { |(_records, join_records)| join_records }
        .flatten(1)
    end

    def record_join_record_pairs(parent_record, collection, depth, &block)
      (collection || []).map { |associated_object|
        record, *other_join_records = block.call(
          mapping_name,
          associated_object,
          no_foreign_key = {},
          depth + depth_modifier,
        )

        join_foreign_keys = foreign_keys(parent_record, record)
        join_record_depth = depth + join_record_depth_modifier

        # TODO: This is a bit hard to figure out
        #
        # The block defined in GraphSerializer#updated_nodes_recursive (inspect the block to confirm)
        # join_foreign_keys is the two foreign key values in a hash
        # the hash is two of the arugments here
        # first one is normally an object to be serialized but serializing this hash will just return the same hash
        # second one is the foreign keys that would need to accompany the object
        #
        # Passing it twice like this is allows it to go though the GraphSerializer like a regular user defined object

        join_records = block.call(
          join_mapping_name,
          join_foreign_keys, # normally this is the object which gets serialized
          join_foreign_keys, # normally this is the foreign key data the object doesn't know about
          join_record_depth
        ).flatten(1)

        [record] + other_join_records + join_records
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

    def depth_modifier
      0
    end

    def join_record_depth_modifier
      +1
    end
  end
end
