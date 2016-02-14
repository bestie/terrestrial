module SequelMapper
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
      record_as_loaded = storage.fetch(hash_key(record), NotFound)

      record != record_as_loaded
    end

    def reject_unchanged_fields(record)
      record_as_loaded = storage.fetch(hash_key(record), {})

      record.reject { |field, value|
        value == record_as_loaded.fetch(field, NotFound)
      }
    end

    private

   NotFound = Module.new

    def hash_key(record)
      deep_clone([record.namespace, record.identity])
    end

    def deep_clone(record)
      Marshal.load(Marshal.dump(record))
    end
  end
end
