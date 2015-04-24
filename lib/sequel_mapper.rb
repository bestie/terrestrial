require "logger"

module SequelMapper
  extend self

  LOGGER = Logger.new(STDERR)

  def config(database_connection)
    Configurations::ConventionalConfiguration.new(database_connection)
  end

  def mapper(config:, name:, datastore:)
    dataset = datastore[config.fetch(:users).namespace]
    identity_map = IdentityMap.new({})
    dirty_map = DirtyMap.new({})

    SequelMapper::MapperFacade.new(
      mappings: config,
      mapping_name: name,
      datastore: datastore,
      dataset: dataset,
      identity_map: identity_map,
      dirty_map: dirty_map,
    )
  end

  private

  def config_to_mappings(config)
    Hash[
      configs.map { |name, config|
        [
          name,
          SequelMapper::RelationMapping.new(
            name: name,
            namespace: config.fetch(:namespace),
            fields: config.fetch(:fields),
            primary_key: config.fetch(:primary_key),
            serializer: serializer.call(config.fetch(:fields) + config.fetch(:associations).keys),
            associations: config.fetch(:associations),
            factory: config.fetch(factory),
          )
        ]
      }
    ]
  end

  class DirtyMap
    def initialize(storage)
      @storage = storage
    end

    attr_reader :storage
    private     :storage

    def load(record)
      storage.store(record.identity, deep_dup(record))
      record
    end

    def dirty?(identity, record)
      loaded_value = storage.fetch(record.identity, :not_found)

      loaded_value != record
    end

    private

    def deep_dup(record)
      Marshal.load(Marshal.dump(record))
    end
  end

  class IdentityMap
    def initialize(storage)
      @storage = storage
    end

    attr_reader :storage
    private     :storage

    def call(record, &not_already_loaded)
      storage.fetch(record.identity) {
        storage.store(
          record.identity,
          not_already_loaded.nil? ? record : not_already_loaded.call(record),
        )
      }
    end
  end

  require "fetchable"
  class MapperRegistry
    include Fetchable

    def initialize(mapper_factory:, datastore:, config:, dirty_map:)
      @mapper_factory = mapper_factory
      @datastore = datastore
      @config = config
      @dirty_map = dirty_map

      @mappers = {}
    end

    attr_reader :mapper_factory, :datastore, :config, :dirty_map, :mappers
    private     :mapper_factory, :datastore, :config, :dirty_map, :mappers

    def [](name)
      mappers.fetch(name) {
        mappers.store(name, create_mapper(name))
      }
    end

    alias_method :from, :[]

    def create_mapper(name)
      mapping = config.fetch(name)

      mapper_factory.call(
        relation: datastore[mapping.relation_name],
        mapping: mapping,
        dirty_map: dirty_map,
      )
    end
  end
end

require "sequel_mapper/mapper_facade"
