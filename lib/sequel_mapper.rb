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

  class DirtyMap
    def initialize(storage)
      @storage = storage
    end

    attr_reader :storage
    private     :storage

    def load(record)
      storage.store(hash_key(record), deep_clone(record))
      record
    end

    def dirty?(record)
      record_as_loaded = storage.fetch(hash_key(record), :not_found)

      record != record_as_loaded
    end

    private

    def hash_key(record)
      deep_clone([record.namespace, record.identity])
    end

    def deep_clone(record)
      Marshal.load(Marshal.dump(record))
    end
  end

  class IdentityMap
    def initialize(storage)
      @storage = storage
    end

    attr_reader :storage
    private     :storage

    def call(record, object)
      storage.fetch(hash_key(record)) {
        storage.store(hash_key(record), object)
      }
    end

    private

    def hash_key(record)
      [record.namespace, record.identity]
    end
  end
end

require "sequel_mapper/mapper_facade"
