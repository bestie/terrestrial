require "sequel_mapper/dataset"

module SequelMapper
  class ManyToManyAssociation
    def initialize(mapping_name:, foreign_key:, key:, proxy_factory:, association_foreign_key:, association_key:, through_mapping_name:, through_dataset:, order:)
      @mapping_name = mapping_name
      @foreign_key = foreign_key
      @key = key
      @proxy_factory = proxy_factory
      @association_foreign_key = association_foreign_key
      @association_key = association_key
      @through_mapping_name = through_mapping_name
      @through_dataset = through_dataset
      @order = order
    end

    attr_reader :mapping_name, :through_mapping_name

    attr_reader :foreign_key, :key, :proxy_factory, :association_key, :association_foreign_key, :through_dataset, :order
    private     :foreign_key, :key, :proxy_factory, :association_key, :association_foreign_key, :through_dataset, :order

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

    def eager_superset(superset, associated_dataset)
      # TODO: All these keys can be confusing, write some focused tests.
      join_dataset = Dataset.new(
        through_dataset
          .where(foreign_key => associated_dataset.select(association_key))
          .to_a
      )

      eager_dataset = superset
        .where(key => join_dataset.select(association_foreign_key))
        .to_a

      JoinedDataset.new(eager_dataset, join_dataset)
    end

    def build_query(superset, parent_record)
      order
        .apply(
          superset.join(through_mapping_name, association_foreign_key => key)
            .where(foreign_key => foreign_key_value(parent_record))
        )
        .lazy.map { |record|
          [record, [foreign_keys(parent_record, record)]]
        }
    end

    class JoinedDataset < Dataset
      def initialize(records, join_records)
        @records = records
        @join_records = join_records
      end

      def join(_relation_name, _conditions)
        # TODO: This works for the current test suite but is probably too
        # simplistic. Perhaps if the dataset was aware of its join conditions
        # it would be able to intellegently skip joining or delegate
        self
      end

      def where(criteria)
        self.class.new(
          *decompose_set(
            find_like_sequel(criteria)
          )
        )
      end

      private

      def decompose_set(set)
        set.map(&:to_pair).transpose.+([ [], [] ]).take(2)
      end

      def find_like_sequel(criteria)
        joined_records
          .select { |record|
            criteria.all? { |k, v|
              record.fetch(k, :nope) == v
            }
          }
      end

      def joined_records
        # TODO: there will inevitably nearly always be a mismatch between the
        # number of records and unique join records. This zip/transpose
        # approach may be too simplistic.
        @joined_records ||= records
          .zip(@join_records)
          .map { |record, join_record|
            JoinedRecord.new(record, join_record)
          }
      end

      class JoinedRecord
        def initialize(record, join_record)
          @record = record
          @join_record = join_record
        end

        attr_reader :record, :join_record
        private      :record, :join_record

        def to_pair
          [record, join_record]
        end

        def to_h
          @record
        end

        def fetch(key, default = NO_DEFAULT, &block)
          args = [key, default].reject { |a| a == NO_DEFAULT }

          @record.fetch(key) {
            @join_record.fetch(*args, &block)
          }
        end

        NO_DEFAULT = Module.new
      end
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
          block.call(through_mapping_name, fks, fks)
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
