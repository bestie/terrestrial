require "terrestrial/error"
require "terrestrial/upserted_record"
require "terrestrial/deleted_record"

module Terrestrial
  class RelationMapping
    def initialize(name:, namespace:, fields:, primary_key:, factory:, serializer:, associations:, subsets:)
      @name = name
      @namespace = namespace
      @fields = fields
      @primary_key = primary_key
      @factory = factory
      @serializer = serializer
      @associations = associations
      @subsets = subsets
    end

    attr_reader :name, :namespace, :fields, :primary_key, :factory, :serializer, :associations, :subsets
    private :factory, :serializer

    def add_association(name, new_association)
      @associations = associations.merge(name => new_association)
    end

    def load(record)
      factory.call(record)
    rescue => e
      raise LoadError.new(namespace, factory, record, e)
    end

    def serialize(object, depth, foreign_keys = {})
      object_attributes = serializer.call(object)

      [
        record(object_attributes, depth, foreign_keys),
        extract_associations(object_attributes) # extract_association_fields
      ]
    rescue => e
      raise SerializationError.new(name, serializer, object, e)
    end

    def delete(object, depth)
      object_attributes = serializer.call(object)

      [deleted_record(object_attributes, depth)]
    end

    private

    def record(attributes, depth, foreign_keys)
      UpsertedRecord.new(
        namespace,
        primary_key,
        select_mapped_fields(attributes).merge(foreign_keys),
        depth,
      )
    end

    def deleted_record(attributes, depth)
      DeletedRecord.new(
        namespace,
        primary_key,
        attributes,
        depth,
      )
    end

    def extract_associations(attributes)
      Hash[
        associations.map { |name, _association|
          [ name, attributes.fetch(name) ]
        }
      ]
    end

    def select_mapped_fields(attributes)
      attributes.select { |name, _value| fields.include?(name) }
    end
  end
end
