require "sequel_mapper/graph_serializer"
require "sequel_mapper/graph_loader"

module SequelMapper
  class MapperFacade
    def initialize(mappings:, mapping_name:, datastore:, dataset:)
      @mappings = mappings
      @mapping_name = mapping_name
      @datastore = datastore
      @dataset = dataset
    end

    attr_reader :mappings, :mapping_name, :datastore, :dataset
    private     :mappings, :mapping_name, :datastore, :dataset

    def save(graph)
      record_dump = graph_serializer.call(mapping_name, graph)

      record_dump.each do |record|
        upsert(record)
      end

      self
    end

    def where(query)
      dataset.map { |record|
        graph_loader.call(mapping_name, record)
      }
    end

    private

    def get_associations(mapping, record)
    end

    def graph_serializer
      GraphSerializer.new(mappings: mappings)
    end

    def graph_loader
      GraphLoader.new(mappings: mappings)
    end

    def mapping
      mappings.fetch(mapping_name)
    end

    def upsert(record)
      existing = datastore[record.namespace].where(record.identity)

      if existing.empty?
        datastore[record.namespace].insert(record.to_h)
      else
        existing.update(record.to_h)
      end
    end
  end
end
