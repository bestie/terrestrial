module SequelMapper
  extend self

  def mapper(datastore:, top_level_namespace:, relation_mappings:)
    Graph.new(
      datastore: datastore,
      top_level_namespace: top_level_namespace,
      relation_mappings: relation_mappings,
    )
  end
end

require "sequel_mapper/graph"
