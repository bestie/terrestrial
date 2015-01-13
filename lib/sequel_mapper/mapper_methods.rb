module SequelMapper
  module MapperMethods
    private

    def relation
      datastore[relation_name]
    end

    def relation_name
      mapping.relation_name
    end

    def row_loader_func
      ->(row) {
        register_row_loaded(row)
        mapping.load(row)
      }
    end

    def register_row_loaded(row)
      dirty_map.store(row.fetch(:id), row)
    end

    def unless_already_persisted(thing, &not_persisted_callback)
      unless persisted_objects.include?(thing)
        persisted_objects.push(thing)
        not_persisted_callback.call(thing)
      end
    end

    def upsert_if_dirty(row)
      loaded_row = dirty_map.fetch(row.fetch(:id), :not_found_therefore_dirty)

      if loaded_row != row
        upsert(row)
      end
    end

    def upsert(row)
      existing = relation.where(id: row.fetch(:id))

      if existing.empty?
        relation.insert(row)
      else
        existing.update(row)
      end
    end

    def persisted_objects
      @persisted_objects ||= []
    end

    def dirty_map
      @dirty_map or raise "Dirty map not set for #{self.class}"
    end
  end
end
