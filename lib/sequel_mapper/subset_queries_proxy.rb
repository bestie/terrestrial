module Terrestrial
  class SubsetQueriesProxy
    def initialize(query_map)
      @query_map = query_map
    end

    def execute(superset, name, *params)
      @query_map.fetch(name).call(superset, *params)
    end
  end
end
