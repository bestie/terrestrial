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
      pp object.id
      dump_associations(object)
      serialize(object)
    end

    private

    def associations(row)
      pp row
      Hash[
        @associations.map { |label, assoc|
          [label, assoc.load(row)]
        }
      ]
    end

    def dump_associations(object)
      @associations.each do |name, assoc|
        assoc.dump(object.public_send(name))
      end
    end

    def serialize(object)
      Serializer.new(fields, object).to_h
    end
  end
end
