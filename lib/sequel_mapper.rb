module SequelMapper
  extend self

  def mapper(datastore:, top_level_namespace:, mappings:, dirty_map:)
    RootMapper.new(
      relation: datastore[top_level_namespace],
      mapping: mappings[top_level_namespace],
      dirty_map: dirty_map,
    )
  end
end

require "sequel_mapper/root_mapper"
