module SequelMapper
  class GraphLoader
    def initialize(mappings:, object_load_pipeline:)
      @mappings = mappings
      @object_load_pipeline = object_load_pipeline
    end

    attr_reader :mappings, :object_load_pipeline

    def call(mapping_name, record)
      mapping = mappings.fetch(mapping_name)

      associations = mapping.associations.map { |association_name, assoc_config|
        [
          association_name,
          case assoc_config.fetch(:type)
          when :one_to_many
            load_one_to_many(record, association_name, assoc_config)
          when :many_to_many
            load_many_to_many(record, association_name, assoc_config)
          when :many_to_one
            load_many_to_one(record, association_name, assoc_config)
          else
            raise "Association type not supported"
          end
        ]
      }

      object_load_pipeline.call(mapping) { |record|
        mapping.factory.call(record.merge(Hash[associations]))
      }.call(record)
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
        loader: object_load_pipeline.call(mapping) { |record|
          call(config.fetch(:mapping_name), record)
        },
      )
    end

    def load_many_to_one(record, name, config)
      mapping = mappings.fetch(config.fetch(:mapping_name))
      foreign_key_value = record.fetch(config.fetch(:foreign_key))
      key_field = config.fetch(:key)

      config.fetch(:proxy_factory).call(
        query: ->(datastore) {
          datastore[mapping.namespace].where(key_field => foreign_key_value).first
        },
        loader: object_load_pipeline.call(mapping) { |record|
          call(config.fetch(:mapping_name), record)
        },
        preloaded_data: {
          key_field => foreign_key_value,
        },
      )
    end

    def load_many_to_many(record, name, config)
      mapping = mappings.fetch(config.fetch(:mapping_name))
      foreign_key_value = record.fetch(config.fetch(:key))
      foreign_key_field = config.fetch(:foreign_key)

      config.fetch(:proxy_factory).call(
        query: ->(datastore) {
          datastore[mapping.namespace].where(
            config.fetch(:association_key) => datastore[config.fetch(:through_namespace)]
              .select(config.fetch(:key))
              .where(foreign_key_field => foreign_key_value)
          )
        },
        loader: object_load_pipeline.call(mapping) { |record|
          call(config.fetch(:mapping_name), record)
        },
      )
    end
  end
end
