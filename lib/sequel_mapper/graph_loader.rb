module SequelMapper
  class GraphLoader
    def initialize(mappings: mappings)
      @mappings = mappings
      @identity_map = {}
    end

    attr_reader :mappings, :identity_map

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

      identity_mapped_loader(mapping) { |record|
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
        loader: identity_mapped_loader(mapping) { |record|
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
        loader: identity_mapped_loader(mapping) { |record|
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
        loader: identity_mapped_loader(mapping) { |record|
          call(config.fetch(:mapping_name), record)
        },
      )
    end

    def identity_mapped_loader(mapping, &loader)
      primary_key_fields = mapping.primary_key

      ->(record) {
        primary_key = primary_key_fields.map { |f| record.fetch(f) }
        identity_map_key = [mapping.namespace, primary_key]

        identity_map.fetch(identity_map_key) {
          identity_map.store(
            identity_map_key,
            loader.call(record),
          )
        }
      }
    end
  end
end
