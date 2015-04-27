module SequelMapper
  class GraphLoader
    def initialize(datastore:, mappings:, object_load_pipeline:)
      @datastore = datastore
      @mappings = mappings
      @object_load_pipeline = object_load_pipeline
    end

    attr_reader :datastore, :mappings, :object_load_pipeline

    def call(mapping_name, record)
      mapping = mappings.fetch(mapping_name)

      associations = mapping.associations.map { |association_name, assoc_config|
        assoc_mapping = mappings.fetch(assoc_config.fetch(:mapping_name))

        [
          association_name,
          case assoc_config.fetch(:type)
          when :one_to_many
            OneToMany.new(self, datastore, object_load_pipeline, assoc_mapping, assoc_config).call(record)
            # load_one_to_many(record, association_name, assoc_config)
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
      }.call(record.to_h) # TODO Try removing this #to_h and the other pipeline calls
    end

    private

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

    def load_many_to_many(source_record, name, config)
      mapping = mappings.fetch(config.fetch(:mapping_name))
      foreign_key_value = source_record.fetch(config.fetch(:key))
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
          pipeline_join_table_record(config, source_record, record)
          call(config.fetch(:mapping_name), record)
        },
        mapper: :not_a_mapper,
      )
    end

    def pipeline_join_table_record(config, source_record, record)
      # TODO This creates a mapping for the join table on the fly and is a
      # bit hard to understand what's happening
      join_mapping = RelationMapping.new(
        namespace: config.fetch(:through_namespace),
        primary_key: [config.fetch(:foreign_key), config.fetch(:association_foreign_key)],
        fields: [],
        factory: :noop,
        serializer: :default,
      )

      join_record = {
        config.fetch(:foreign_key) => source_record.fetch(config.fetch(:key)),
        config.fetch(:association_foreign_key) => record.fetch(config.fetch(:association_key)),
      }

      object_load_pipeline.call(join_mapping).call(join_record)
    end
  end

  class OneToMany
    def initialize(graph_loader, datastore, object_load_pipeline, mapping, config)
      @graph_loader = graph_loader
      @datastore = datastore
      @mapping = mapping
      @config = config
      @object_load_pipeline = object_load_pipeline
    end

    attr_reader :graph_loader, :datastore, :mapping, :config, :object_load_pipeline

    def call(record)
      config.fetch(:proxy_factory).call(
        query: ->(datastore) {
          datastore[mapping.namespace].where(foreign_key_field => foreign_key_value(record))
        },
        loader: object_load_pipeline.call(mapping) { |record|
          graph_loader.call(config.fetch(:mapping_name), record)
        },
        mapper: self,
      )
    end

    def eager_load(dataset, association_name)
      foreign_keys = dataset.map { |record| foreign_key_value(record) }
      eager_dataset = datastore[mapping.namespace].where(
        foreign_key_field => foreign_keys,
      ).to_a

      config.fetch(:proxy_factory).call(
        query: ->(_) { eager_dataset },
        loader: object_load_pipeline.call(mapping) { |record|
          graph_loader.call(config.fetch(:mapping_name), record)
        },
        mapper: self,
      )
    end

    private

    def foreign_key_value(record)
      record.fetch(config.fetch(:key))
    end

    def foreign_key_field
      config.fetch(:foreign_key)
    end
  end
end
