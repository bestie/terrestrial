require "sequel_mapper/upserted_record"
require "sequel_mapper/deleted_record"

module SequelMapper
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

      # TODO may need some attention :)
      mapping = mappings.fetch(mapping_name)

      current_record, association_fields = mapping.serialize(
        object,
        depth,
        parent_foreign_keys,
      )

      serialization_map.store(object, current_record)

      associated_records = mapping.associations
        .map { |name, association|
          [association_fields.fetch(name), association]
        }
        .map { |collection, association|
          [nodes(collection), deleted_nodes(collection), association]
        }
        .map { |nodes, deleted_nodes, association|
          assoc_mapping = mappings.fetch(association.mapping_name)

          association.dump(current_record, nodes, depth) { |assoc_mapping_name, assoc_object, foreign_key, assoc_depth|
            call(assoc_mapping_name, assoc_object, assoc_depth, foreign_key).tap { |associated_record, *_join_records|
              # TODO: remove this mutation
              current_record.merge!(association.extract_foreign_key(associated_record))
            }
          } +
          association.delete(current_record, deleted_nodes, depth) { |assoc_mapping_name, assoc_object, foreign_key, assoc_depth|
            delete(assoc_mapping_name, assoc_object, assoc_depth, foreign_key)
          }
        }

      ([current_record] + associated_records).flatten(1)
    end

    private

    def delete(mapping_name, object, depth, _foreign_key)
      mapping = mappings.fetch(mapping_name)
      serialized_record = mapping.serializer.call(object)

      [
        DeletedRecord.new(
          mapping.namespace,
          mapping.primary_key,
          serialized_record,
          depth,
        )
      ]
    end

    def nodes(collection)
      if collection.respond_to?(:each_loaded)
        collection.each_loaded
      elsif collection.is_a?(Struct)
        [collection]
      elsif collection.respond_to?(:each)
        collection.each
      else
        [collection]
      end
    end

    def deleted_nodes(collection)
      if collection.respond_to?(:each_deleted)
        collection.each_deleted
      else
        []
      end
    end
  end
end
