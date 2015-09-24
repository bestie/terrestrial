module SequelMapper
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
