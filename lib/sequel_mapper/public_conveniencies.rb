require "sequel_mapper/identity_map"
require "sequel_mapper/dirty_map"
require "sequel_mapper/mapper_facade"

module SequelMapper
  module PublicConveniencies
    def config(database_connection)
      Configurations::ConventionalConfiguration.new(database_connection)
    end

    def mapper(config:, name:, datastore:)
      dataset = datastore[config.fetch(:users).namespace]
      identity_map = IdentityMap.new({})
      dirty_map = DirtyMap.new({})

      MapperFacade.new(
        mappings: config,
        mapping_name: name,
        datastore: datastore,
        dataset: dataset,
        identity_map: identity_map,
        dirty_map: dirty_map,
      )
    end
  end
end
