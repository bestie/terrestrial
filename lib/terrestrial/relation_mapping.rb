require "terrestrial/error"
require "terrestrial/upsert_record"
require "terrestrial/deleted_record"

module Terrestrial
  class RelationMapping
    def initialize(name:, namespace:, fields:, database_owned_fields:, database_default_fields:, primary_key:, factory:, serializer:, associations:, subsets:, observers:)
      @name = name
      @namespace = namespace
      @fields = fields
      @database_owned_fields = database_owned_fields
      @database_default_fields = database_default_fields
      @primary_key = primary_key
      @factory = factory
      @serializer = serializer
      @associations = associations
      @subsets = subsets
      @observers = observers

      @incoming_foreign_keys = []
    end

    attr_reader :name, :namespace, :fields, :database_owned_fields, :database_default_fields, :primary_key, :factory, :serializer, :associations, :subsets, :created_at_field, :updated_at_field, :observers
    private :factory, :serializer, :observers

    def add_association(name, new_association)
      @associations = associations.merge(name => new_association)
    end

    def register_foreign_key(fk)
      @incoming_foreign_keys += fk
    end

    def load(record)
      factory.call(reject_non_factory_fields(record))
    rescue => e
      raise LoadError.new(namespace, factory, record, e)
    end

    def serialize(object, depth, foreign_keys = {})
      object_attributes = serializer.call(object)

      record = upsertable_record(object, object_attributes, depth, foreign_keys)
      observers.each { |o| o.post_serialize(self, object, record) }

      [
        record,
        extract_associations(object_attributes)
      ]
    rescue => e
      raise SerializationError.new(name, serializer, object, e)
    end

    def delete(object, depth)
      object_attributes = serializer.call(object)

      [deleted_record(object_attributes, depth)]
    end

    def post_save(object, record, new_attributes)
      new_record = upsertable_record(object, new_attributes, 0, {})

      observers.each { |o| o.post_save(self, object, record, new_record) }

      record.merge!(new_attributes)
    end

    private

    def upsertable_record(object, attributes, depth, foreign_keys)
      UpsertRecord.new(
        self,
        object,
        select_mapped_fields(attributes).merge(foreign_keys),
        depth,
      )
    end

    def deleted_record(attributes, depth)
      DeletedRecord.new(
        self,
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

    def reject_non_factory_fields(attributes)
      attributes.reject { |name, _value| (@incoming_foreign_keys + local_foreign_keys).include?(name) }
    end

    def factory_fields
      @factory_fields ||= fields - (local_foreign_keys + @incoming_foreign_keys)
    end

    def local_foreign_keys
      @local_foreign_keys ||= associations.values.flat_map(&:local_foreign_keys)
    end
  end
end
