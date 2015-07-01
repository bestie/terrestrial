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
      @eager_data = {}
    end

    attr_reader :mappings, :mapping_name, :datastore, :dataset, :identity_map, :dirty_map
    private     :mappings, :mapping_name, :datastore, :dataset, :identity_map, :dirty_map

    def save(graph)
      record_dump = graph_serializer.call(mapping_name, graph)

      object_dump_pipeline.call(record_dump)

      self
    end

    def all
      self
    end

    def where(query)
      new_with_dataset(
        dataset.where(query)
      )
    end

    include Enumerable
    def each(&block)
      dataset
        .map { |record|
          graph_loader.call(mapping_name, record, Hash[@eager_data])
        }
        .each(&block)
    end

    def eager_load(association_name_map)
      @eager_data = eager_load_the_things(mapping, dataset, association_name_map)

      self
    end

    private

    def eager_load_the_things(mapping, parent_dataset, association_name_map)
      association_name_map
        .flat_map { |name, deeper_association_names|
          association = mapping.associations.fetch(name)
          association_mapping = mappings.fetch(association.mapping_name)
          association_namespace = association_mapping.namespace
          association_dataset = get_eager_dataset(association, association_namespace, parent_dataset)

          [
            [[mapping.name, name] , association_dataset]
          ] + eager_load_the_things(association_mapping, association_dataset, deeper_association_names)
        }
    end

    def get_eager_dataset(association, association_namespace, parent_dataset)
      SequelMapper::Dataset.new(
        association.eager_superset(
          datastore[association_namespace],
          parent_dataset,
        ).to_a
      )
    end

    def new_with_dataset(new_dataset)
      self.class.new(
        dataset: new_dataset,
        mappings: mappings,
        mapping_name: mapping_name,
        datastore: datastore,
        identity_map: identity_map,
        dirty_map: dirty_map,
      )
    end

    def graph_serializer
      GraphSerializer.new(mappings: mappings)
    end

    def graph_loader
      GraphLoader.new(
        datasets: datastore,
        mappings: mappings,
        object_load_pipeline: object_load_pipeline,
      )
    end

    def object_load_pipeline
      ->(mapping, &callback){
        ->(record) {
          [
            namespaced_record_factory(mapping), # TODO terrible terrible naming
            dirty_map.method(:load),
            identity_map,
          ].reduce(record) { |agg, operation|
            operation.call(agg, &callback)
          }
        }
      }
    end

    require "pp"
    def object_dump_pipeline
      ->(records) {
        [
          :uniq.to_proc,
          ->(rs) { puts "After unique filter"; pp rs },
          ->(rs) { rs.select { |r| dirty_map.dirty?(r.identity, r) } },
          ->(rs) { puts "After dirty filter"; pp rs },
          ->(rs) { rs.map(&method(:upsert)) },
        ].reduce(records) { |agg, operation|
          operation.call(agg)
        }
      }
    end

    def namespaced_record_factory(mapping)
      ->(record_hash) {
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
      # TODO I doubt this is really more performant but fewer queries register :)
      row_count = datastore[record.namespace]
        .where(record.identity)
        .update(record.to_h)

      if row_count < 1
        row_count = datastore[record.namespace].insert(record.to_h)
      end

      row_count
    end
  end
end
