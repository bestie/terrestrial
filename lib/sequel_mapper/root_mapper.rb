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
      # TODO consider fixing this
      unless relation.respond_to?(:where)
        raise "Cannot perform datastore query after eager load"
      end

      new_with_dataset(
        relation.where(criteria)
      )
    end

    def query(name)
      new_with_dataset(
        mapping.get_query(name).call(relation)
      )
    end

    def save(graph_root)
      relation.db.transaction do
        upsert_if_dirty(mapping.dump(graph_root))
      end
    end

    def eager_load(association_name)
      rows = relation.to_a
      association_by_name(association_name).eager_load(rows)
      new_with_dataset(rows)
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
