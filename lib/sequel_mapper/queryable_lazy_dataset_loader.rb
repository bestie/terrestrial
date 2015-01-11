require "forwardable"

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

  def where(criteria)
    self.class.new(database_enum.where(criteria), loader)
  end

  def each(&block)
    database_enum
      .map(&loader)
      .each(&block)
  end
end
