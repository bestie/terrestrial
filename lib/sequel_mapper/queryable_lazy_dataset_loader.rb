class QueryableLazyDatasetLoader
  def initialize(database_enum, loader)
    @database_enum = database_enum
    @loader = loader
  end

  attr_reader :database_enum, :loader
  private     :database_enum, :loader

  extend Forwardable
  def_delegators :database_enum, :where

  def where(criteria)
    @database_enum = database_enum.where(criteria)
    self
  end

  def each(&block)
    database_enum
      .map(&loader)
      .each(&block)
  end
end
