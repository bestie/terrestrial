require "sequel_mapper/serializer"

module SequelMapper
  class Mapping
    def initialize(relation_name:, factory:, serializer:, fields:, associations:, queries:)
      @relation_name = relation_name
      @factory = factory
      @serializer = serializer
      @fields = fields
      @associations = associations
      @queries = queries
    end

    attr_reader :relation_name
    attr_reader :factory, :fields
    private :factory, :fields

    def load(row)
      factory.call(row.merge(associations(row)))
    end

    def dump(object)
      dump_associations(object)
      serialize_with_foreign_keys(object)
    end

    def fetch_association(name)
      @associations.fetch(name)
    end

    def add_association(name, mapper)
      @associations[name] = mapper
    end

    def mark_foreign_key(field_name)
      @fields = @fields - [field_name]
    end

    def get_query(name)
      @queries.fetch(name) {
        raise "#{name} is not a registered query for relation named #{relation_name}"
      }
    end

    private

    def associations(row)
      Hash[
        @associations
          .map { |label, assoc|
            [label, assoc.load_for_row(row)]
          }
      ]
    end

    def dump_associations(object)
      # TODO: This approach requires that all entities' associations are
      # exposed via public methods. Figure out how to allow the associated
      # collectons to remain private to the object and still traverse and
      # persist effieciently. Perhaps keep them in a registry or handle it via
      # serialization, keeping track of which fields are associations, similar
      # to how foreign_keys are handled.
      @associations.each do |name, assoc|
        assoc.save(object, object.public_send(name))
      end
    end

    def serialize_with_foreign_keys(object)
      @associations.reduce(serialize(object)) { |agg, (label, assoc)|
        agg.merge(assoc.foreign_key_field(label, object))
      }
    end

    def serialize(object)
      @serializer.call(fields, object)
    end
  end
end
