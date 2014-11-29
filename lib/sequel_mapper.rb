module SequelMapper
  extend self

  def mapper(datastore:, top_level_namespace:, relation_mappings:)
    Mapper.new(
      datastore: datastore,
      top_level_namespace: top_level_namespace,
      relation_mappings: relation_mappings,
    )
  end
end

require "sequel_mapper/mapper"
