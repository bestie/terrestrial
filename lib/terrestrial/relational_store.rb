require "terrestrial/graph_serializer"
require "terrestrial/graph_loader"
require "terrestrial/inspection_string"

module Terrestrial
  class RelationalStore
    include Enumerable
    include InspectionString

    def initialize(mappings:, mapping_name:, datastore:, load_pipeline:, dump_pipeline:, dataset: nil)
      @mappings = mappings
      @mapping_name = mapping_name
      @datastore = datastore
      @dataset = dataset
      @load_pipeline = load_pipeline
      @dump_pipeline = dump_pipeline
      @eager_data = {}
    end

    attr_reader :mappings, :mapping_name, :datastore, :load_pipeline, :dump_pipeline
    private     :mappings, :mapping_name, :datastore, :load_pipeline, :dump_pipeline

    def save(graph)
      record_dump = serialize_graph(graph)

      dump_pipeline.call(record_dump)

      self
    end

    def changes_sql(graph)
      changes(graph).map { |record|
        datastore.changes_sql(record)
      }
    end

    def changes(graph)
      changes, _ = dump_pipeline
        .take_until(:remove_unchanged_fields)
        .call(
          serialize_graph(graph)
        )

      changes
    end

    def all
      self
    end

    def where(query)
      new_with_dataset(
        dataset.where(query)
      )
    end

    def subset(name, *params)
      new_with_dataset(
        mapping.subsets.execute(dataset, name, *params)
      )
    end

    def each(&block)
      dataset
        .map { |record|
          graph_loader.call(mapping_name, record, @eager_data)
        }
        .each(&block)
    end

    def eager_load(association_name_map)
      @eager_data = eager_load_associations(mapping, dataset, association_name_map)

      self
    end

    def delete(object)
      dump_pipeline.call(
        serialize_graph(object)
          .select { |record| record.depth == 0 }
          .reverse
          .take(1)
          .map { |record| DeletedRecord.new(mapping, record.attributes, 0) }
      )
    end

    private

    def serialize_graph(graph)
      graph_serializer.call(mapping_name, graph)
    end

    def eager_load_associations(mapping, parent_dataset, association_name_map)
      Hash[
        association_name_map.map { |name, deeper_association_names|
          association = mapping.associations.fetch(name)
          association_mapping = mappings.fetch(association.mapping_name)
          association_dataset = get_eager_dataset(association, parent_dataset)

          [
            name,
            {
              superset: association_dataset,
              associations: eager_load_associations(
                association_mapping,
                association_dataset,
                deeper_association_names,
              ),
            }
          ]
        }
      ]
    end

    def get_eager_dataset(association, parent_dataset)
      association.eager_superset(
        association_root_datasets(association),
        parent_dataset,
      )
    end

    def association_root_datasets(association)
      association
        .mapping_names
        .map { |name| mappings.fetch(name) }
        .map(&:namespace)
        .map { |ns| datastore[ns] }
    end

    def new_with_dataset(new_dataset)
      self.class.new(
        dataset: new_dataset,
        mappings: mappings,
        mapping_name: mapping_name,
        datastore: datastore,
        load_pipeline: load_pipeline,
        dump_pipeline: dump_pipeline,
      )
    end

    def graph_serializer
      GraphSerializer.new(mappings: mappings)
    end

    def graph_loader
      GraphLoader.new(
        datasets: datastore,
        mappings: mappings,
        object_load_pipeline: load_pipeline,
      )
    end

    def dataset
      @dataset ||= datastore[mapping.namespace]
    end

    def mapping
      mappings.fetch(mapping_name)
    end

    def inspectable_properties
      [
        :mapping_name,
        :dataset,
        :eager_load,
      ]
    end
  end
end
