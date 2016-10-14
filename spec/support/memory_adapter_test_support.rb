require "support/mock_sequel"

module Terrestrial
  module MemoryAdapterTestSupport
    module_function def build_datastore(schema, raw_storage = {})
      MockSequel.build_from_schema(schema.fetch(:tables), raw_storage)
    end

    module_function def excluded_adapters
      "sequel"
    end

    module_function def before_suite(_schema)
      # NOOP
    end

    module_function def query_counter
      # NOOP
    end
  end
end
