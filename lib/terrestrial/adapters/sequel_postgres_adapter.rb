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
        row = perform_upsert_returning_row(record)
        record.on_upsert(row)
        nil
      rescue Object => e
        raise UpsertError.new(record.namespace, record.to_h, e)
      end

      def delete(record)
        database[record.namespace].where(record.identity).delete
      end

      def changes_sql(record)
        generate_upsert_sql(record)
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

      def relations
        database.tables - [:schema_migrations]
      end

      def relation_fields(relation_name)
        database[relation_name].columns
      end

      def schema(relation_name)
        database.schema(relation_name)
      end

      private

      def perform_upsert_returning_row(record)
        sql = generate_upsert_sql(record)
        result = database[sql]
          .to_a
          .fetch(0) { {} }
      end

      def generate_upsert_sql(record)
        table_name = record.namespace
        update_attributes = record.updatable? && record.updatable_attributes

        primary_key_fields = primary_key(table_name)

        missing_not_null_fields = database.schema(table_name)
          .reject { |field_name, _| record.attributes.keys.include?(field_name) }
          .select { |_field_name, properties|
            allow_null = properties.fetch(:allow_null, true)
            not_null = !allow_null
            default = properties.fetch(:default, nil)
            no_default = !default

            not_null && no_default
          }
          .map(&:first)
          .reject { |field_name| record.identity_fields.include?(field_name) }

        missing_not_null_attrs = missing_not_null_fields
          .map { |field_name| [field_name, database[table_name].select(field_name).where(record.identity)] }
          .to_h

        # TODO: investigate if failing to find a private key results in extra schema queries
        if primary_key_fields.any?
          if record.id?
            conflict_fields = primary_key_fields
          else
            return database[table_name]
              .returning(Sequel.lit("*"))
              .insert_sql(record.insertable.merge(missing_not_null_attrs))
          end
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

        # TODO: Use specific field list instead of Sequel.lit("*")
        database[table_name]
          .insert_conflict(**upsert_args)
          .returning(Sequel.lit("*"))
          .insert_sql(record.insertable.merge(missing_not_null_attrs))
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
