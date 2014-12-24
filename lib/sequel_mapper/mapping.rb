module SequelMapper
  class Mapping
    def initialize(relation_name:, factory:, fields:, associations:)
      @relation_name = relation_name
      @factory = factory
      @fields = fields
      @associations = associations
    end

    attr_reader(:relation_name, :factory, :fields)

    def load(row)
      factory.call(row.merge(associations(row)))
    end

    def associations(row)
      pp row
      Hash[
        @associations.map { |label, assoc|
          [label, assoc.load(row)]
        }
      ]
    end
  end
end
