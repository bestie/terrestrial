require "sequel"

module SequelMapper
  module SequelTestSupport
    def create_database
      `psql postgres --command "CREATE DATABASE $PGDATABASE;"`
    end
    module_function :create_database

    def drop_database
      `psql postgres --command "DROP DATABASE $PGDATABASE;"`
    end
    module_function :drop_database

    def drop_tables
      db_connection.tables.each do |table_name|
        db_connection.drop_table(table_name)
      end
    end
    module_function :drop_tables

    def truncate_tables
      db_connection.tables.each do |table_name|
        db_connection[table_name].truncate
      end
    end
    module_function :truncate_tables

    def db_connection
      Sequel.default_timezone = :utc
      @db_connection ||= Sequel.postgres(
        host: ENV.fetch("PGHOST"),
        user: ENV.fetch("PGUSER"),
        database: ENV.fetch("PGDATABASE"),
      )
    end
    module_function :db_connection

    def create_tables(schema)
      options_map = {
        id: { primary_key: true },
      }

      schema.each do |table_name, fields|

        db_connection.create_table(table_name) do
          fields.each do |field|
            type = field.fetch(:type)
            name = field.fetch(:name)
            options = options_map.fetch(name, {})

            send(type, name, options)
          end
        end
      end
    end
    module_function :create_tables

    def insert_records(datastore, records)
      records.each { |(namespace, record)|
        datastore[namespace].insert(record)
      }
    end

    class QueryCounter
      def initialize
        reset
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

      def update_count
        updates.count
      end

      def updates
        @info
          .map { |query| query.gsub(/\A\([0-9\.]+s\) /, "") }
          .select { |query| query.start_with?("UPDATE") }
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

      def reset
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
