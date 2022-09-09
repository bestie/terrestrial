require "terrestrial/adapters/abstract_adapter"

module Terrestrial
  module Adapters
    class ActiveRecordPostgresAdapter
      extend Forwardable
      include Adapters::AbstractAdapter

      def initialize(database)
        unless database.is_a? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
          raise "no!"
        end
        @database = database
      end

      attr_reader :database
      private     :database

      def tables
        database.tables.map(&:to_sym)
      end

      def primary_key(table_name)
        # schema_cache?
        Array(database.primary_key(table_name)).map(&:to_sym)
      end

      def [](table_name)
        Dataset.new(
          database,
          arel_table(table_name).project("*"),
        )
      end

      def upsert(record)
        sql = upsert_sql(record)
        database.exec_query(sql)
      rescue Object => e
        raise UpsertError.new(record.namespace, record.to_h, e)
      end

      def delete(record)
        table = arel_table(record.namespace)
        identity = record.identity.map { |k,v| table[k].eq(v) }

        delete_manager = Arel::DeleteManager.new
        delete_manager.from(table).where(identity)
        database.exec_delete(delete_manager.to_sql)
      end

      def upsert_sql(record)
        insert = Insert.new(arel_table(record.namespace), record, database)
        database.build_insert_sql(insert)
      end

      def changes_sql(record)
        generate_upsert_sql(record)
      rescue Object => e
        raise UpsertError.new(record.namespace, record.to_h, e)
      end

      def execute(sql)
        database.execute(sql)
      end

      def conflict_fields(table_name)
        primary_key(table_name)
      end

      def unique_indexes(table_name)
        database.indexes(table_name)
          .select { |index| index.unique }
          .map { |index| index.columns.map(&:to_sym) }
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

      def select_from_arel_table(name)
        arel_table(name).project("*")
      end

      def arel_table(name)
        Arel::Table.new(name)
      end

      def arel_attribute(table, column_name, value)
        table[column_name].eq(value)
      end

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
      class Dataset
        extend Forwardable
        extend WrapDelegate
        include Enumerable

        def initialize(connection, arel)
          @connection = connection
          @arel = arel
        end

        attr_reader :connection, :arel
        private     :connection, :arel

        # wrap_delegators :dataset, [
        #   :select,
        #   :where,
        #   :clone,
        #   :order,
        # ]
        #
        # def_delegators :dataset, *[
        #   :empty?,
        #   :delete,
        #   :opts,
        #   :sql,
        #   :reverse,
        # ]

        def cache_sql?
          false
        end

        def each(&block)
          connection.execute(arel.to_sql).each(&block)
        end
      end

      class Insert
        def initialize(arel_table, record, database)
          @arel_table = arel_table
          @record = record
          @database = database
        end

        attr_reader :arel_table, :record, :database

        def attributes
          record.to_h
        end

        def arel_insert
          @arel_insert ||= Arel::InsertManager
            .new(arel_table)
            .insert(attributes.transform_keys { |name| arel_table[name] })
        end

        def into
          "INTO #{arel_table.name} (#{columns_list}) VALUES"
        end

        def columns_list
          attributes.keys.join(",")
        end

        def values_list
          parens(attributes.values.map { |v| "'"+database.quote_string(v)+"'" }.join(","))
        end

        def conflict_target
          parens(record.identity_fields.map(&:to_s).join(","))
        end

        def returning
          "id"
        end

        def skip_duplicates?
          false
        end

        def update_duplicates?
          true
        end

        def raw_update_sql?
          false
        end

        def touch_model_timestamps_unless(&block)
          ""
        end

        def updatable_columns
          record.insertable.keys
        end

        private

        def parens(string)
          "(#{string})"
        end
      end
    end
  end
end
