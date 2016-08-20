module Terrestrial
  class GraphLoader
    def initialize(datasets:, mappings:, object_load_pipeline:)
      @datasets = datasets
      @mappings = mappings
      @object_load_pipeline = object_load_pipeline
    end

    attr_reader :datasets, :mappings, :object_load_pipeline

    def call(mapping_name, record, eager_data_graph = {})
      mapping = mappings.fetch(mapping_name)

      load_record(mapping, record, eager_data_graph)
    end

    private

    def load_record(mapping, record, eager_data_graph)
      associations = load_associations(mapping, record, eager_data_graph)

      object_load_pipeline.call(mapping, record, Hash[associations])
    end

    def load_associations(mapping, record, eager_data_graph)
      mapping.associations.map { |name, association|
        load_association(name, association, record, eager_data_graph)
      }
    end

    def load_association(name, association, record, eager_data_graph)
      association_superset, deeper_eager_data = eager_or_lazy_data(
        name,
        association,
        eager_data_graph,
      )

      [
        name,
        association.build_proxy(
          record: record,
          data_superset: association_superset,
          loader: recursive_loader(association, deeper_eager_data),
        )
      ]
    end

    def eager_or_lazy_data(name, association, eager_data_graph)
      eager_data = eager_data_graph.fetch(name, {})

      association_superset = eager_data.fetch(:superset) { default_dataset(association) }
      deeper_eager_data = eager_data.fetch(:associations, {})

      [association_superset, deeper_eager_data]
    end

    def default_dataset(association)
      association
        .mapping_names
        .map { |name| mappings.fetch(name) }
        .map(&:namespace)
        .map { |ns| datasets[ns] }
    end

    def recursive_loader(association, eager_data_graph)
      ->(associated_record, join_records = []) {
        load_and_ignore_join_records(association, join_records)

        call(
          association.mapping_name,
          associated_record,
          eager_data_graph,
        )
      }
    end

    def load_and_ignore_join_records(association, join_records)
      join_records.each do |jr|
        mapping = mappings.fetch(association.join_mapping_name)
        object_load_pipeline.call(mapping, jr)
      end

      nil
    end
  end
end
