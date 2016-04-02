module Terrestrial
  class IdentityMap
    def initialize(storage)
      @storage = storage
    end

    attr_reader :storage
    private     :storage

    def call(mapping, record, object)
      storage.fetch(hash_key(mapping, record)) {
        storage.store(hash_key(mapping, record), object)
      }
    end

    private

    def hash_key(mapping, record)
      [mapping.name, record.namespace, record.identity]
    end
  end
end
