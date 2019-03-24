module Terrestrial
  class DirtyMap
    def initialize(storage)
      @storage = storage
    end

    attr_reader :storage
    private     :storage

    def load_if_new(record)
      storage.fetch(hash_key(record)) { self.load(record) }
      record
    end

    def load(record)
      storage.store(hash_key(record), record.deep_clone)
      record
    end

    def dirty?(record)
      !same_as_loaded?(record) || deleted?(record)
    end

    def reject_unchanged_fields(record)
      record_as_loaded = storage.fetch(hash_key(record), {})

      record.reject { |field, value|
        value == record_as_loaded.fetch(field, NotFound)
      }
    end

    private

    NotFound = Module.new

    def same_as_loaded?(record)
      record_as_loaded = storage.fetch(hash_key(record), NotFound)

      if record_as_loaded == NotFound
        false
      else
        record.subset?(record_as_loaded)
      end
    end

    def deleted?(record)
      record.if_delete { return true }
      return false
    end

    def hash_key(record)
      [record.namespace, record.identity]
    end
  end
end
