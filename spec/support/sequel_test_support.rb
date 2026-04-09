require "sequel"

module Terrestrial
  module SequelTestSupport
    module_function def rename_table(old, new)
      db_connection.rename_table(old, new)
    end

    module_function def execute(sql)
      db_connection[sql].to_a
    end

    module_function def adapter
      @adapter ||= Terrestrial::Adapters::SequelPostgresAdapter.new(db_connection)
    end

    module_function def db_connection
      @db_connection ||= Sequel.postgres(
        host: ENV.fetch("PGHOST"),
        user: ENV.fetch("PGUSER"),
        database: ENV.fetch("PGDATABASE"),
      ).tap { |db|
        db.loggers << query_counter
        db["SET TIME ZONE 'UTC'"].to_a
        Sequel.default_timezone = :utc
        Sequel.database_timezone = :utc
      }
    end

    module_function def before
      query_counter.reset!
      clean_database
    end

    module_function def before_suite(schema)
      drop_tables
      create_tables(schema.fetch(:tables))
      add_unique_indexes(schema.fetch(:unique_indexes))
      add_foreign_keys(schema.fetch(:foreign_keys))
    end

    module_function def after_suite
      drop_tables
      connection_pool.checkin(db_connection)
    end

    module_function def query_counter
      @query_counter ||= QueryCounter.new
    end

    module_function def after_suite
      drop_tables
    end

    module_function def create_database
      `psql postgres --command "CREATE DATABASE $PGDATABASE;"`
    end

    module_function def drop_database
      `psql postgres --command "DROP DATABASE $PGDATABASE;"`
    end

    module_function def drop_tables(tables = db_connection.tables)
      tables.each do |table_name|
        db_connection.drop_table(table_name, cascade: true)
      end
    end

    module_function def clean_database(tables = db_connection.tables)
      stardard_test_tables = BLOG_SCHEMA.fetch(:tables).keys
      test_tables_in_deletable_order = stardard_test_tables.reverse

      clean_tables(test_tables_in_deletable_order)
    end

    module_function def clean_tables(names)
      names.each do |name|
        clean_table(name)
      end
    end

    module_function def clean_table(name)
      db_connection[name].delete
    end

    module_function def db_connection
      @db_connection ||= begin
         Sequel.postgres(
           host: ENV.fetch("PGHOST"),
           user: ENV.fetch("PGUSER"),
           password: ENV.fetch("PGPASSWORD"),
           database: ENV.fetch("PGDATABASE"),
         ).tap { Sequel.default_timezone = :utc }
       end
    end

    module_function def create_tables(tables)
      tables.each do |table_name, fields|
        db_connection.create_table(table_name) do
          fields.each do |field|
            type = field.fetch(:type)
            name = field.fetch(:name)
            options = field.fetch(:options, {})

            column(name, type, options)
          end
        end
      end

      tables.keys
    end

    module_function def add_unique_indexes(unique_indexes)
      unique_indexes.each do |(table, *cols)|
        db_connection.alter_table(table) do
          add_unique_constraint(cols)
        end
      end
    end

    module_function def add_foreign_keys(foreign_keys)
      default_options = { deferrable: false, on_delete: :set_null }

      foreign_keys.each do |(table, fk_col, foreign_table, key_col, options)|
        options_with_defaults = default_options
          .merge(options || {})
          .merge(key: key_col)

        db_connection.alter_table(table) do
          add_foreign_key([fk_col], foreign_table, options_with_defaults)
        end
      end
    end

    module_function def convert_to_adapter_keys(attr_hash)
      attr_hash.stringify_keys
    end

    module_function def get_next_sequence_value(table_name)
      execute("select currval(pg_get_serial_sequence('#{table_name}', 'id'))")
        .to_a
        .fetch(0)
        .fetch(:currval) + 1
    rescue Sequel::DatabaseError => e
      if /PG::ObjectNotInPrerequisiteState/.match?(e.message)
        1
      else
        raise e
      end
    end

    class QueryCounter
      def initialize
        reset!
      end

      def read_count
        @info
          .grep(/SELECT/)
          .grep_v(list_tables_query_pattern)
          .grep_v(columns_query_pattern)
          .grep_v(pg_attribute_pattern)
          .count
      end

      def delete_count
        @info.count { |query|
          /\A\([0-9\.]+s\) DELETE/i === query
        }
      end

      def write_count
        upserts.count
      end

      def update_count
        updates.count
      end

      def insert_count
        inserts.count
      end

      def upserts
        @info.grep(/INSERT .+ ON CONFLICT/)
      end

      def updates
        @info.grep(/\A\([0-9\.]+s\) UPDATE/)
      end

      def inserts
        @info.grep(/\A\([0-9\.]+s\) INSERT/)
      end

      def show_queries
        puts @info.join("\n")
      end

      def info(message)
        @info.push(message)
      end

      def error(message)
        @error.push(message)
      end

      def warn(message)
        @warn.push(message)
      end

      def reset!
        @info = []
        @error = []
        @warn = []
      end

      private

      def list_tables_query_pattern
        /SELECT "relname" FROM "pg_class"/
      end

      def pg_attribute_pattern
        /SELECT pg_attribute.attname AS/
      end

      def columns_query_pattern
        /SELECT \* FROM .+ LIMIT 0/
      end
    end
  end
end
