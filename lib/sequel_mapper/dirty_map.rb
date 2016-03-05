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
      return true if record_as_loaded == NotFound

      unknown_keys?(record_as_loaded, record) ||
        record_changed?(record_as_loaded, record)
    end

    def reject_unchanged_fields(record)
      record_as_loaded = storage.fetch(hash_key(record), {})

      record.reject { |field, value|
        value == record_as_loaded.fetch(field, NotFound)
      }
    end

    private

    NotFound = Module.new

    def record_changed?(previous, current)
      !!(current.keys & previous.keys).detect { |key|
        current.fetch(key) != previous.fetch(key)
      }
    end

    def hash_key(record)
      deep_clone([record.namespace, record.identity])
    end

    def deep_clone(record)
      Marshal.load(Marshal.dump(record))
    end
  end
end
