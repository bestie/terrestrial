module Terrestrial
  class GraphSerializer
    def initialize(mappings:)
      @mappings = mappings
      @serialization_map = {}
    end

    attr_reader :mappings, :serialization_map
    private     :mappings, :serialization_map

    def call(mapping_name, object, depth = 0, parent_foreign_keys = {})
      if serialization_map.include?(object)
        return [serialization_map.fetch(object)]
      end

      mapping = mappings.fetch(mapping_name)

      current_record, association_fields = mapping.serialize(
        object,
        depth,
        parent_foreign_keys,
      )

      serialization_map.store(object, current_record)

      (
        [current_record] + associated_records(mapping, current_record, association_fields, depth)
      ).flatten(1)
    end

    private

    def associated_records(mapping, current_record, association_fields, depth)
      mapping
        .associations
        .map { |name, association|
          dump_association(
            association,
            current_record,
            association_fields.fetch(name),
            depth,
          )
        }
    end

    def dump_association(association, current_record, collection, depth)
      updated_nodes_recursive(association, current_record, collection, depth) + 
        deleted_nodes(association, current_record, collection, depth)
    end

    def updated_nodes_recursive(association, current_record, collection, depth)
      association.dump(current_record, get_loaded(collection), depth) { |assoc_mapping_name, assoc_object, pass_down_foreign_key, assoc_depth|
        recurse(current_record, association, assoc_mapping_name, assoc_object, assoc_depth, pass_down_foreign_key)
      }
    end

    def recurse(current_record, association, assoc_mapping_name, assoc_object, assoc_depth, foreign_key)
      (assoc_object && call(assoc_mapping_name, assoc_object, assoc_depth, foreign_key))
        .tap { |associated_record, *_join_records|
          current_record.merge!(association.extract_foreign_key(associated_record))
        }
    end

    def deleted_nodes(association, current_record, collection, depth)
      nodes = get_deleted(collection)
      association.delete(current_record, nodes, depth) { |assoc_mapping_name, assoc_object, foreign_key, assoc_depth|
        delete(assoc_mapping_name, assoc_object, assoc_depth, foreign_key)
      }
    end

    def delete(mapping_name, object, depth, _foreign_key)
      mapping = mappings.fetch(mapping_name)
      mapping.delete(object, depth)
    end

    def get_loaded(collection)
      if collection.respond_to?(:_loaded_nodes)
        collection._loaded_nodes
      elsif collection.is_a?(Struct)
        [collection]
      elsif collection.respond_to?(:each)
        collection.each
      elsif collection.nil?
        [nil]
      else
        [collection]
      end
    end

    def get_deleted(collection)
      if collection.respond_to?(:_deleted_nodes)
        collection._deleted_nodes
      else
        []
      end
    end
  end
end
