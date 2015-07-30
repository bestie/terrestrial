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
      associations = mapping.associations

      serialized_record = serializer.call(object)

      current_record = NamespacedRecord.new(
        namespace,
        record_identity(primary_key, serialized_record),
        serialized_record
          .select { |k, _v| fields.include?(k) }
          .merge(foreign_key),
      )

      # return [] if lazy_and_not_loaded?(object)
      @count += 1
      LOGGER.info "Dump #{@count} #{object.id}"

      if stack.include?(current_record)
        return [current_record]
      end

      [current_record] + associations
        .map { |name, config|
          [serialized_record.fetch(name), config]
        }
        .map { |collection, config|
          [non_loading_enum(collection).to_a, config]
        }
        .reject { |collection, _| collection.empty? }
        .flat_map { |collection, config|
          assoc_mapping = mappings.fetch(config.mapping_name)

          config.dump(current_record, collection) { |assoc_mapping_name, assoc_object, foreign_key|
            call(assoc_mapping_name, assoc_object, foreign_key, stack + [current_record])
          }
        }
    end

    private

    def non_loading_enum(collection)
      if collection.respond_to?(:each_loaded)
        collection.each_loaded
      else
        collection.each
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
