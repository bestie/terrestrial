require "forwardable"

module SequelMapper
  class QueryableLazyDatasetLoader
    extend Forwardable
    include Enumerable

    def initialize(database_enum, loader, association_mapper = :mapper_not_provided)
      @database_enum = database_enum
      @loader = loader
      @association_mapper = association_mapper
    end

    attr_reader :database_enum, :loader
    private     :database_enum, :loader

    def_delegators :database_enum, :where

    def eager_load(association_name)
      @association_mapper.eager_load_association(database_enum, association_name)
    end

    def where(criteria)
      self.class.new(database_enum.where(criteria), loader)
    end

    def first
      loader.call(database_enum.first)
    end

    def each(&block)
      database_enum
        .map(&loader)
        .each(&block)
    end
  end
end
