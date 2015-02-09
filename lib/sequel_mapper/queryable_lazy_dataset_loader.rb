require "short_inspection_string"

module SequelMapper
  class QueryableLazyDatasetLoader
    include ShortInspectionString
    include Enumerable

    def initialize(database_enum, loader, mapper)
      @database_enum = database_enum
      @loader = loader
      @mapper = mapper
      @loaded = false
    end

    attr_reader :database_enum, :loader, :mapper
    private     :database_enum, :loader, :mapper

    def eager_load(association_name)
      mapper.eager_load_association(database_enum, association_name)
    end

    def where(criteria)
      self.class.new(database_enum.where(criteria), loader, mapper)
    end

    def query(name)
      self.class.new(
        mapper
          .get_query(name)
          .call(database_enum),
        loader,
        mapper,
      )
    end

    def each(&block)
      database_enum
        .map { |row| mark_as_loaded; row }
        .map(&loader)
        .each(&block)
    end

    def loaded?
      !!@loaded
    end

    private

    def mark_as_loaded
      @loaded ||= true
    end

    def inspectable_properties
      [
        :database_enum,
        :loaded,
      ]
    end
  end
end
