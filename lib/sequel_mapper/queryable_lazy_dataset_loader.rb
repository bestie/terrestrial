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
      mapper.eager_load(database_enum, association_name)
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
      enum.each(&block)
    end

    def each_loaded(&block)
      loaded_objects.each(&block)
    end

    private

    def enum
      @enum ||= Enumerator.new { |yielder|
        loaded_objects.each do |obj|
          yielder.yield(obj)
        end

        loop do
          object_enum.next.tap { |obj|
            loaded_objects.push(obj)
            yielder.yield(obj)
          }
        end
      }
    end

    def object_enum
      @object_enum ||= database_enum.lazy.map(&loader)
    end

    def loaded_objects
      @loaded_objects ||= []
    end

    def inspectable_properties
      [
        :database_enum,
        :loaded,
      ]
    end
  end
end
