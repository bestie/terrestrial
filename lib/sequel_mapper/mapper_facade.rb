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

    def where(query)
      dataset.map { |record|
        mapping.factory.call(
          record.merge(get_associations(mapping, record))
        )
      }
    end

    private

    def get_associations(mapping, record)
      mapping.associations.map { |association_name, assoc_config|
        case assoc_config.fetch(:type)
        when :one_to_many
          require "pry"; binding.pry
        else
          rasie "Association type not supported"
        end
      }
    end

    def graph_serializer
      GraphSerializer.new(mappings: mappings)
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
