module SequelMapper
  module MapperMethods
    private

    def relation
      datastore[relation_name]
    end

    def relation_name
      mapping.relation_name
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

    def register_load(row)
      dirty_map.store(row.fetch(:id), row)
    end

    def persisted_objects
      @persisted_objects ||= []
    end
  end

  class RootMapper
    include MapperMethods

    def initialize(datastore:, mapping:, dirty_map:)
      @datastore = datastore
      @mapping = mapping
      @dirty_map = dirty_map
    end

    attr_reader :datastore, :mapping, :dirty_map
    private     :datastore, :mapping, :dirty_map

    def where(criteria)
      relation
        .where(criteria)
        .map { |row| register_load(row) }
        .map { |row| mapping.load(row) }
    end

    def save(graph_root)
      upsert_if_dirty(mapping.dump(graph_root))
    end
  end
end
