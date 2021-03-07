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
        :tables,
      ]

      def [](table_name)
        Dataset.new(database[table_name])
      end

      def upsert(record)
        prepared_upsert(record).insert(record.to_h)
      rescue Object => e
        raise UpsertError.new(record.namespace, record.to_h, e)
      end

      def delete(record)
        database[record.namespace].where(record.identity).delete
      end

      def changes_sql(record)
        prepared_upsert(record).insert_sql(record.to_h)
      rescue Object => e
        raise UpsertError.new(record.namespace, record.to_h, e)
      end

      def conflict_fields(table_name)
        primary_key(table_name)
      end

      def primary_key(table_name)
        [database.primary_key(table_name)]
          .compact
          .map(&:to_sym)
      end

      def unique_indexes(table_name)
        database.indexes(table_name).map { |_name, data|
          data.fetch(:columns)
        }
      end

      private

      def prepared_upsert(record)
        table_name = record.namespace
        update_attributes = record.updatable? && record.updatable_attributes

        primary_key_fields = primary_key(table_name)

        # TODO: investigate if failing to find a private key results in extra schema queries
        if primary_key_fields.any?
          conflict_fields = primary_key_fields
        else
          u_idxs = unique_indexes(table_name)
          if u_idxs.any?
            conflict_fields = u_idxs.first
          end
        end

        upsert_args = { update: update_attributes }

        if conflict_fields && conflict_fields.any?
          upsert_args.merge!(target: conflict_fields)
        end

        database[table_name].insert_conflict(**upsert_args)
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
