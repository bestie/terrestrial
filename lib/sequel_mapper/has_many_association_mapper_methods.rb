module SequelMapper
  module HasManyAssociationMapperMethods
    def added_nodes(collection)
      collection.respond_to?(:added_nodes) ? collection.added_nodes : collection
    end

    def removed_nodes(collection)
      collection.respond_to?(:removed_nodes) ? collection.removed_nodes : []
    end

    def nodes_to_persist(collection)
      if loaded?(collection)
        collection
      else
        added_nodes(collection)
      end
    end
  end
end
