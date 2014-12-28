require "sequel_mapper/dumper"

module SequelMapper
  class Mapper
    def initialize(datastore:, mapping:)
      @datastore = datastore
      @mapping = mapping
    end

    attr_reader :datastore, :mapping
    private     :datastore, :mapping

    def where(criteria)
      datastore[top_level_namespace]
        .where(criteria)
        .map { |row| mapping.load(row) }
    end

    def save(graph_root)
      @persisted_objects = []
      dump(top_level_namespace, graph_root)
    end

    private

    def top_level_namespace
      mapping.relation_name
    end

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
  end
end
