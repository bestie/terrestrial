module SequelMapper
  extend self

  def config(database_connection)
    Configurations::ConventionalConfiguration.new(database_connection)
  end

  def mapper(datastore:, config:, dirty_map: {})
    SequelMapper::MapperFacade.new(
      mappings: config,
      mapping_name: :users,
      datastore: datastore,
      dataset: datastore[:users],
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
