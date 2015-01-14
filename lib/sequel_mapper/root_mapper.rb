require "sequel_mapper/mapper_methods"

module SequelMapper
  class RootMapper
    include MapperMethods

    def initialize(relation:, mapping:, dirty_map:)
      @relation = relation
      @mapping = mapping
      @dirty_map = dirty_map
    end

    attr_reader :relation, :mapping
    private     :relation, :mapping

    def where(criteria)
      relation
        .where(criteria)
        .map(&row_loader_func)
    end

    def save(graph_root)
      upsert_if_dirty(mapping.dump(graph_root))
    end
  end
end
