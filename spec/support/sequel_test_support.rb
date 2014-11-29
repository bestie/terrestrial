require "sequel"

module SequelMapper
  module SequelTestSupport
    def create_database
      `psql postgres --command "CREATE DATABASE $PGDATABASE;"`
    end
    module_function :create_database

    def db_connection
      Sequel.postgres(
        host: ENV.fetch("PGHOST"),
        user: ENV.fetch("PGUSER"),
        database: ENV.fetch("PGDATABASE"),
      )
    end
    module_function :db_connection

    class QueryCounter
      def initialize
        reset
      end

      def read_count
        @info.count { |query|
          /\A\([0-9\.]+s\) SELECT/i === query
        }
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
        @info = []
        @error = []
        @warn = []
      end
    end
  end
end
