module Terrestrial
  class GraphLoader
    def initialize(datasets:, mappings:, object_load_pipeline:)
      @datasets = datasets
      @mappings = mappings
      @object_load_pipeline = object_load_pipeline
    end

    attr_reader :datasets, :mappings, :object_load_pipeline

    def call(mapping_name, record, eager_data = {})
      mapping = mappings.fetch(mapping_name)

      load_record(mapping, record, eager_data)
    end

    private

    def load_record(mapping, record, eager_data)
      associations = load_associations(mapping, record, eager_data)

      object_load_pipeline.call(mapping, record, Hash[associations])
    end

    def load_associations(mapping, record, eager_data)
      mapping.associations.map { |name, association|
        assoc_eager_data = eager_data.fetch(name, {})

        data_superset = assoc_eager_data.fetch(:superset) {
          load_from_datasets(association)
        }
        eager_association_data = assoc_eager_data.fetch(:associations, {})

        [
          name,
          association.build_proxy(
            record: record,
            data_superset: data_superset,
            loader: recursive_loader(association, eager_association_data),
          )
        ]
      }
    end

    def load_from_datasets(association)
      association
        .mapping_names
        .map { |name| mappings.fetch(name) }
        .map(&:namespace)
        .map { |ns| datasets[ns] }
    end

    def recursive_loader(association, eager_data)
      ->(associated_record, join_records = []) {
        join_records.map { |jr|
          join_mapping = mappings.fetch(association.join_mapping_name)
          object_load_pipeline.call(join_mapping, jr)
        }

        call(
          association.mapping_name,
          associated_record,
          eager_data,
        )
      }
    end
  end
end
