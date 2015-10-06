module SequelMapper
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
        data_superset = eager_data.fetch([mapping.name, name]) {
          datasets[mappings.fetch(association.mapping_name).namespace]
        }

        [
          name,
          association.build_proxy(
            record: record,
            data_superset: data_superset,
            loader: ->(associated_record, join_records = []) {
              join_records.map { |jr|
                join_mapping = mappings.fetch(association.join_mapping_name)
                object_load_pipeline.call(join_mapping, jr)
              }
              call(association.mapping_name, associated_record, eager_data)
            },
          )
        ]
      }
    end
  end
end
