module SequelMapper
  class Mapping
    def initialize(relation_name:, factory:, fields:, associations:)
      @relation_name = relation_name
      @factory = factory
      @fields = fields
      @associations = associations
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
      Serializer.new(fields, object).to_h
    end
  end
end
