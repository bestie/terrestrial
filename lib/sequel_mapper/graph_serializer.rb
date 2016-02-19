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

    def call(mapping_name, object, parent_foreign_keys = {})
      if serialization_map.include?(object)
        return [serialization_map.fetch(object)]
      end

      # TODO may need some attention :)
      mapping = mappings.fetch(mapping_name)
      serializer = mapping.serializer
      namespace = mapping.namespace
      primary_key = mapping.primary_key
      fields = mapping.fields
      associations_map = mapping.associations

      serialized_record = serializer.call(object)

      current_record = UpsertedRecord.new(
        namespace,
        record_identity(primary_key, serialized_record),
        serialized_record
          .select { |k, _v| fields.include?(k) }
          .merge(parent_foreign_keys)
      )

      serialization_map.store(object, current_record)

      associated_records = associations_map
        .map { |name, association|
          [serialized_record.fetch(name), association]
        }
        .map { |collection, association|
          [nodes(collection), deleted_nodes(collection), association]
        }
        .map { |nodes, deleted_nodes, association|
          assoc_mapping = mappings.fetch(association.mapping_name)

          association.dump(current_record, nodes) { |assoc_mapping_name, assoc_object, foreign_key|
            call(assoc_mapping_name, assoc_object, foreign_key).tap { |associated_record, *_join_records|
              # TODO: remove this mutation
              current_record.merge!(association.extract_foreign_key(associated_record))
            }
          } +
          association.delete(current_record, deleted_nodes) { |assoc_mapping_name, assoc_object, foreign_key|
            delete(assoc_mapping_name, assoc_object, foreign_key)
          }
        }

      (associated_records + [current_record]).flatten(1)
    end

    private

    def delete(mapping_name, object, _foreign_key)
      # TODO copypasta ¯\_(ツ)_/¯
      mapping = mappings.fetch(mapping_name)
      primary_key = mapping.primary_key
      serializer = mapping.serializer
      namespace = mapping.namespace

      serialized_record = serializer.call(object)

      [
        DeletedRecord.new(
          namespace,
          record_identity(primary_key, serialized_record),
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
        collection
      end
    end

    def deleted_nodes(collection)
      if collection.respond_to?(:each_deleted)
        collection.each_deleted
      else
        []
      end
    end

    def record_identity(primary_key, record)
      Hash[
        primary_key.map { |field|
          [field, record.fetch(field)]
        }
      ]
    end
  end
end
