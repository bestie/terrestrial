require "active_record"

module Terrestrial
  module ActiveRecordTestSupport
    def all_users
      adapter_support.db_connection.execute("SELECT * FROM users").to_a
    end

    module_function def execute(sql)
      db_connection.execute(sql)
    end

    module_function def adapter
      Adapters::ActiveRecordPostgresAdapter.new(db_connection)
    end

    module_function def db_connection
      @db_connection ||= begin
        connection = connection_pool.checkout
        # The query_counter will let us make assertions about how efficiently
        # the database is being used
      end
    end

    module_function def before
      query_counter.reset!
      ActiveRecord::Base.logger = query_counter
      ActiveSupport::LogSubscriber.colorize_logging = false
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
      @@query_counter ||= QueryCounter.new
    end

    module_function def create_database
      `psql postgres --command "CREATE DATABASE $PGDATABASE;"`
    end

    module_function def drop_database
      `psql postgres --command "DROP DATABASE $PGDATABASE;"`
    end

    module_function def drop_tables(tables = db_connection.tables)
      tables.each do |table_name|
        db_connection.drop_table(table_name, force: :cascade)
      end
    end

    module_function def clean_database(tables = db_connection.tables)
      stardard_test_tables = BLOG_SCHEMA.fetch(:tables).keys
      test_tables_in_deletable_order = stardard_test_tables.reverse

      clean_tables(test_tables_in_deletable_order)
    end

    module_function def clean_tables(names)
      db_connection.truncate_tables(*names)
      # names.each do |name|
      #   clean_table(name)
      # end
    end

    module_function def connection_pool
      @connection_pool ||= begin
        ActiveRecord::Base.establish_connection(
          adapter:  "postgresql",
          host: ENV.fetch("PGHOST"),
          user: ENV.fetch("PGUSER"),
          database: ENV.fetch("PGDATABASE"),
        )
      end
    end

    module_function def create_tables(tables)
      tables.each do |table_name, fields|
        db_connection.create_table(table_name, id: false) do |table|
          fields.each do |field|
            type = field.fetch(:type).name.downcase.to_sym
            name = field.fetch(:name)
            options = field.fetch(:options, {})

            table.column(name, type, options)
          end
        end
      end

      tables.keys
    end

    module_function def add_unique_indexes(unique_indexes)
      unique_indexes.each do |(table, *cols)|
        db_connection.add_index(table, cols, unique: true)
      end
    end

    module_function def add_foreign_keys(foreign_keys)
      default_options = { deferrable: false, on_delete: :nullify }

      foreign_keys.each do |(table, fk_col, foreign_table, key_col, options)|
        options_with_defaults = default_options.merge(options || {})

        begin
          db_connection.add_foreign_key(
            table,
            foreign_table,
            column: fk_col,
            primary_key: key_col,
            **options_with_defaults
          )
        end
      end
    end

    module_function def convert_to_adapter_keys(attr_hash)
      attr_hash.stringify_keys
    end

    module_function def get_next_sequence_value(table_name)
      execute("SELECT currval(pg_get_serial_sequence('#{table_name}', 'id'))")
        .to_a
        .fetch(0)
        .fetch(:currval) + 1
    rescue ActiveRecord::StatementInvalid => e
      if /PG::ObjectNotInPrerequisiteState/.match?(e.message)
        1
      else
        raise e
      end
    end

    class QueryCounter < Logger
      def initialize
        @io = StringIO.new
        super(io, Logger::DEBUG)
      end

      attr_reader :io

      def readlines
        io.rewind
        io.readlines
      end

      def read_count
        read_count_with_describes -
          list_tables_query_count -
          describe_table_queries_count
      end

      def delete_count
        @info.count { |query|
          /\A\([0-9\.]+s\) DELETE/i === query
        }
      end

      def read_count_with_describes
        @info.count { |query|
          /\A\([0-9\.]+s\) SELECT/i === query
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
        @info
          .map { |query| query.gsub(/\A\([0-9\.]+s\) /, "") }
          .select { |query| query.start_with?("INSERT") && query.include?("ON CONFLICT") }
      end

      def updates
        @info
          .map { |query| query.gsub(/\A\([0-9\.]+s\) /, "") }
          .select { |query| query.start_with?("UPDATE") }
      end

      def inserts
        readlines.grep(/SQL .+ INSERT/)
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
        @described_table_queries = []
        @info = []
        @error = []
        @warn = []
      end

      private

      def list_tables_query_count
        @info.count { |query| list_tables_query_pattern.match(query) }
      end

      def describe_table_queries_count
        describe_table_queries.count
      end

      def describe_table_queries
        # TODO this could probably be better solved with finite automata
        described_table_queries = []

        queries_without_table_list
          .take_while { |query|
            described_table_queries.push(query)
            described_table_query_pattern.match(query) &&
              described_table_queries.length == described_table_queries.uniq.length
          }
      end

      def queries_without_table_list
        @info
          .drop_while { |query|
            !list_tables_query_pattern.match(query)
          }
          .drop_while { |query|
            list_tables_query_pattern.match(query)
          }
      end

      def list_tables_query_pattern
        /\A\([0-9\.]+s\) SELECT "relname" FROM "pg_class"/
      end

      def described_table_query_pattern
        /\A\([0-9\.]+s\) SELECT \* FROM "[^"]+" LIMIT 1/i
      end
    end
  end
end
