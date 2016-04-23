require "terrestrial/error"

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
    private :factory

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
        extract_associations(object_attributes)
      ]
    end

    def record(attributes, depth, foreign_keys)
      UpsertedRecord.new(
        namespace,
        primary_key,
        select_mapped_fields(attributes).merge(foreign_keys),
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
