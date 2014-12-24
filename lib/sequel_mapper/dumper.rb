module SequelMapper
  class Dumper
    def initialize(datastore, relation_mappings, dirty_map)
      @datastore = datastore
      @relation_mappings = relation_mappings
      @dirty_map = dirty_map
      @persisted_objects = []
    end

    attr_reader(
      :datastore,
      :relation_mappings,
      :dirty_map,
      :persisted_objects,
    )

    def call(relation_name, object)
      return if persisted_objects.include?(object)
      persisted_objects.push(object)

      relation = relation_mappings.fetch(relation_name)

      row = object_to_row(relation, object)

      # TODO: dirty tracking (for update efficiency) only works for objects
      #       that belong to another when the association is defined in both
      #       directions
      relation.fetch(:belongs_to, []).each do |assoc_name, assoc_config|
        row[assoc_config.fetch(:foreign_key)] = object.public_send(assoc_name).id
      end

      relation.fetch(:has_many, []).each do |assoc_name, assoc_config|
        collection = object.public_send(assoc_name)
        collection_loaded = collection.respond_to?(:loaded?) ?
          collection.loaded? : true

        if collection_loaded
          collection.each do |assoc_object|
            call(assoc_config.fetch(:relation_name), assoc_object)
          end
        end

        next unless collection.respond_to?(:removed_nodes)
        collection.removed_nodes.each do |removed_node|
          datastore[assoc_config.fetch(:relation_name)]
            .where(id: removed_node.id)
            .delete
        end

        # TODO: while these nodes are not persisted twice they are dumped twice
        collection.added_nodes.each do |assoc_object|
          call(assoc_config.fetch(:relation_name), assoc_object)
        end
      end

      relation.fetch(:has_many_through, []).each do |assoc_name, assoc_config|
        collection = object.public_send(assoc_name)
        collection_loaded = collection.respond_to?(:loaded?) ?
          collection.loaded? : true

        if collection_loaded
          collection.each do |assoc_object|
            call(assoc_config.fetch(:relation_name), assoc_object)
          end
        end

        next unless collection.respond_to?(:added_nodes)
        collection.added_nodes.each do |added_node|
          datastore[assoc_config.fetch(:through_relation_name)]
            .insert(
              assoc_config.fetch(:foreign_key) => object.id,
              assoc_config.fetch(:association_foreign_key) => added_node.id,
            )
        end

        collection.removed_nodes.each do |removed_node|
          datastore[assoc_config.fetch(:through_relation_name)]
            .where(assoc_config.fetch(:association_foreign_key) => removed_node.id)
            .delete
        end
      end

      if row_dirty?(row)
        existing = datastore[relation_name]
          .where(id: object.id)

        if existing.empty?
          datastore[relation_name].insert(row)
        else
          existing.update(row)
        end
      end
    end

    private

    def row_dirty?(row)
      loaded_row = dirty_map.fetch(row.fetch(:id), :not_found_therefore_dirty)

      row != loaded_row
    end

    def object_to_row(relation, object)
      object.to_h.select { |field_name, _v|
        relation.fetch(:columns).include?(field_name)
      }
    end
  end
end
