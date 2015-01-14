require "sequel_mapper/mapper_methods"

module SequelMapper
  class RootMapper
    include MapperMethods
    include Enumerable

    def initialize(relation:, mapping:, dirty_map:)
      @relation = relation
      @mapping = mapping
      @dirty_map = dirty_map
    end

    attr_reader :relation, :mapping
    private     :relation, :mapping

    def each(&block)
      relation
        .map(&row_loader_func)
        .each(&block)
    end

    def where(criteria)
      new_with_dataset(
        relation.where(criteria)
      )
    end

    def save(graph_root)
      upsert_if_dirty(mapping.dump(graph_root))
    end

    private

    def new_with_dataset(dataset)
      self.class.new(
        relation: dataset,
        mapping: mapping,
        dirty_map: dirty_map,
      )
    end
  end
end
