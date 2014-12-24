module SequelMapper
  class Loader
    def initialize(datastore, identity_map, dirty_map)
      @datastore = datastore
      @identity_map = identity_map
      @dirty_map = dirty_map
    end

    def call(mapping, row)
      # ensure_loaded_once(row) {
        mapping.load(row)
      # }
    end

    private

    attr_reader(
      :datastore,
      :relation_mappings,
      :identity_map,
      :dirty_map,
    )

    def ensure_loaded_once(row, &block)
      identity_map.fetch(row.fetch(:id), false) or block.call.tap { |object|
          register(object, row)
        }
    end

    # def associations(relation_mappings, relation, row)
    #   {}.merge(has_many_associations(relation_mappings, relation, row))
    #     .merge(has_many_through_associations(relation_mappings, relation, row))
    #     .merge(belongs_to_associations(relation_mappings, relation, row))
    # end

    def register(object, row)
      identity_map.store(row.fetch(:id), object)
      dirty_map.store(row.fetch(:id), row)
    end
  end
end
