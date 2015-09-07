module SequelMapper
  class SubsetQueriesProxy
    def initialize(query_map)
      @query_map = query_map
    end

    def execute(name, dataset)
      @query_map.fetch(name).call(dataset)
    end
  end
end
