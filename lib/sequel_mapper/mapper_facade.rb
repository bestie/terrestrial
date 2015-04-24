require "sequel_mapper/graph_serializer"
require "sequel_mapper/graph_loader"

module SequelMapper
  class MapperFacade
    def initialize(mappings:, mapping_name:, datastore:, dataset:, identity_map:, dirty_map:)
      @mappings = mappings
      @mapping_name = mapping_name
      @datastore = datastore
      @dataset = dataset
      @identity_map = identity_map
      @dirty_map = dirty_map
    end

    attr_reader :mappings, :mapping_name, :datastore, :dataset, :identity_map, :dirty_map
    private     :mappings, :mapping_name, :datastore, :dataset, :identity_map, :dirty_map

    def save(graph)
      record_dump = graph_serializer.call(mapping_name, graph)

      object_dump_pipeline.call(record_dump)

      self
    end

    def where(query)
      dataset.map { |record|
        graph_loader.call(mapping_name, record)
      }
    end

    private

    def graph_serializer
      GraphSerializer.new(mappings: mappings)
    end

    def graph_loader
      GraphLoader.new(
        mappings: mappings,
        object_load_pipeline: object_load_pipeline,
      )
    end

    def object_load_pipeline
      ->(mapping, &callback){
        ->(record) {
          [
            namespaceed_record_factory, # TODO terrible terrible naming
            dirty_map.method(:load),
            identity_map,
          ].reduce(record) { |agg, operation|
            operation.call(mapping, agg, &callback)
          }
        }
      }
    end

    def object_dump_pipeline
      ->(records) {
        [
          :uniq.to_proc,
          ->(rs) { puts "After unique filter"; p rs },
          ->(rs) { rs.select { |r| dirty_map.dirty?(r.namespace, r.identity, r) } },
          ->(rs) { puts "After dirty filter"; p rs },
          ->(rs) { rs.map(&method(:upsert)) },
        ].reduce(records) { |agg, operation|
          operation.call(agg)
        }
      }
    end

    def namespaceed_record_factory
      ->(mapping, record_hash) {
        identity = Hash[
          mapping.primary_key.map { |field|
            [field, record_hash.fetch(field)]
          }
        ]

        SequelMapper::NamespacedRecord.new(
          mapping.namespace,
          identity,
          record_hash,
        )
      }
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
