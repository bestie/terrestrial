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

  class GraphLoader
    def initialize(mappings: mappings)
      @mappings = mappings
    end

    attr_reader :mappings

    def call(mapping_name, record)
      mapping = mappings.fetch(mapping_name)

      associations = mapping.associations.map { |association_name, assoc_config|
        [
          association_name,
          case assoc_config.fetch(:type)
          when :one_to_many
            load_one_to_many(record, association_name, assoc_config)
          when :many_to_many
            []
          when :many_to_one
            []
          else
            raise "Association type not supported"
          end
        ]
      }

      mapping.factory.call(record.merge(Hash[associations]))
    end

    private

    def load_one_to_many(record, name, config)
      mapping = mappings.fetch(config.fetch(:mapping_name))
      foreign_key_value = record.fetch(config.fetch(:key))
      foreign_key_field = config.fetch(:foreign_key)

      config.fetch(:proxy_factory).call(
        query: ->(datastore) {
          datastore[mapping.namespace].where(foreign_key_field => foreign_key_value)
        },
        loader: ->(record) {
          call(config.fetch(:mapping_name), record)
        },
      )
    end
  end
end
