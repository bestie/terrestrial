module SequelMapper
  class RelationMapping
    def initialize(name:, namespace:, fields:, primary_key:, factory:, serializer:, associations:, queries:)
      @name = name
      @namespace = namespace
      @fields = fields
      @primary_key = primary_key
      @factory = factory
      @serializer = serializer
      @associations = associations
      @queries = queries
    end

    attr_reader :name, :namespace, :fields, :primary_key, :factory, :serializer, :associations, :queries

    def add_association(name, new_association)
      @associations = associations.merge(name => new_association)
    end

    private

    def new_with_associations(new_associations)
      self.class.new(
        name: name,
        namespace: namespace,
        fields: fields,
        primary_key: primary_key,
        factory: factory,
        serializer: serializer,
        associations: new_associations,
        queries: queries,
      )
    end
  end
end
