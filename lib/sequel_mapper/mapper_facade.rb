require "sequel_mapper/graph_serializer"

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

    private

    def graph_serializer
      GraphSerializer.new(mappings: mappings)
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
