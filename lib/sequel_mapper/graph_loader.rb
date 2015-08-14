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

      associations = load_associations(mapping, record, eager_data)

      object_load_pipeline.call(mapping) { |pipelined_record|
        mapping.factory.call(pipelined_record.merge(Hash[associations]))
      }.call(record.to_h) # TODO Try removing this #to_h
    end

    private

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
            loader: ->(associated_record) {
              call(association.mapping_name, associated_record, eager_data)
            },
          )
        ]
      }
    end
  end
end
