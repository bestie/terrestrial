require "forwardable"
require "terrestrial/adapters/abstract_adapter"

module Terrestrial
  module WrapDelegate
    def wrap_delegators(target_name, method_names)
      method_names.each do |method_name|
        define_method(method_name) do |*args, &block|
          self.class.new(
            send(target_name).public_send(method_name, *args, &block)
          )
        end
      end
    end
  end

  module SequelDatasetComparisonLiteralAppendPatch
    def ===(other)
      other.is_a?(Adapters::SequelPostgresAdapter::Dataset) or
        super
    end
  end

  Sequel::Dataset.extend(SequelDatasetComparisonLiteralAppendPatch)

  module Adapters
    class SequelPostgresAdapter
      extend Forwardable
      include Adapters::AbstractAdapter

      def initialize(database)
        @database = database
      end

      attr_reader :database
      private     :database

      def_delegators :database, *[
        :transaction,
      ]

      def [](table_name)
        Dataset.new(database[table_name])
      end

      def upsert(record)
        update_attributes = record.updatable? && record.updatable_attributes

        database[record.namespace].insert_conflict(
          target: record.identity_fields, update: update_attributes
        ).insert(record.to_h)
      rescue Object => e
        raise UpsertError.new(record.namespace, record.to_h, e)
      end

      def delete(record)
        database[record.namespace].where(record.identity).delete
      end

      def changes_sql(record)
        update_attributes = record.updatable? && record.updatable_attributes

        database[record.namespace].insert_conflict(
          target: record.identity_fields, update: update_attributes
        ).insert_sql(record.to_h)
      rescue Object => e
        raise UpsertError.new(record.namespace, record.to_h, e)
      end

      class Dataset
        extend Forwardable
        extend WrapDelegate
        include Enumerable

        def initialize(dataset)
          @dataset = dataset
        end

        attr_reader :dataset
        private     :dataset

        wrap_delegators :dataset, [
          :select,
          :where,
          :clone,
          :order,
        ]

        def_delegators :dataset, *[
          :empty?,
          :delete,
          :opts,
          :sql,
          :reverse,
        ]

        def cache_sql?
          false
        end

        def each(&block)
          dataset.each(&block)
        end
      end
    end
  end
end
