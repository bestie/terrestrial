require "sequel_mapper/namespaced_record"

module SequelMapper
  class GraphSerializer
    def initialize(mappings:)
      @mappings = mappings
      @count = 0
    end

    attr_reader :mappings

    def call(mapping_name, object, foreign_key = {}, stack = [])
      # TODO may need some attention :)
      mapping = mappings.fetch(mapping_name)
      serializer = mapping.serializer
      namespace = mapping.namespace
      primary_key = mapping.primary_key
      fields = mapping.fields
      associations_map = mapping.associations

      serialized_record = serializer.call(object)

      current_record = NamespacedRecord.new(
        namespace,
        record_identity(primary_key, serialized_record),
        serialized_record
          .select { |k, _v| fields.include?(k) }
          .merge(foreign_key),
      )

      if stack.include?(current_record)
        return [current_record]
      end

      [current_record] + associations_map
        .map { |name, association|
          [serialized_record.fetch(name), association]
        }
        .map { |collection, association|
          [nodes(collection), deleted_nodes(collection), association]
        }
        .map { |nodes, deleted_nodes, association|
          assoc_mapping = mappings.fetch(association.mapping_name)

          association.dump(current_record, nodes) { |assoc_mapping_name, assoc_object, foreign_key|
            call(assoc_mapping_name, assoc_object, foreign_key, stack + [current_record])
          } +
          association.dump(current_record, deleted_nodes) { |assoc_mapping_name, assoc_object, foreign_key|
            delete(assoc_mapping_name, assoc_object, foreign_key, stack + [current_record])
          }
        }
        .flatten(1)
    end

    private

    def delete(mapping_name, object, foreign_key, stack)
      # TODO copypasta ¯\_(ツ)_/¯
      mapping = mappings.fetch(mapping_name)
      serializer = mapping.serializer
      namespace = mapping.namespace
      primary_key = mapping.primary_key

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

    DeletedRecord = Class.new(NamespacedRecord) do
      def if_upsert(&block)
        self
      end

      def if_delete(&block)
        block.call(self)
        self
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
