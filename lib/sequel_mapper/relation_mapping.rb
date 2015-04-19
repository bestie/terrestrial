module SequelMapper
  class RelationMapping
    def initialize(**config)
      @config = config
    end

    def method_missing(key)
      @config.fetch(key) { super }
    end
  end
end
