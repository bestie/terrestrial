require "sequel_mapper/loader"
require "sequel_mapper/dumper"

module SequelMapper
  class Mapper
    def initialize(datastore:, top_level_namespace:, mappings:)
      @top_level_namespace = top_level_namespace
      @datastore = datastore
      @relation_mappings = mappings
    end

    attr_reader :top_level_namespace, :datastore, :relation_mappings
    private     :top_level_namespace, :datastore, :relation_mappings

    def where(criteria)
      datastore[top_level_namespace]
        .where(criteria)
        .map { |row|
          load(
            relation_mappings.fetch(top_level_namespace),
            row,
          )
        }
    end

    def save(graph_root)
      @persisted_objects = []
      dump(top_level_namespace, graph_root)
    end

    private

    def identity_map
      @identity_map ||= {}
    end

    def dirty_map
      @dirty_map ||= {}
    end

    def dump(namespace, graph_root)
      Dumper.new(datastore, relation_mappings, dirty_map)
        .call(namespace, graph_root)
    end

    def load(relation, row)
      Loader.new(relation_mappings, identity_map, dirty_map)
        .call(relation, row)
    end
  end
end
