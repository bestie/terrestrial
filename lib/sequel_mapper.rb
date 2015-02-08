module SequelMapper
  extend self

  def mapper(datastore:, top_level_mapping:, mappings:, dirty_map:)
    mapping = mappings[top_level_mapping]
    relation_name = mapping.relation_name

    RootMapper.new(
      relation: datastore[relation_name],
      mapping: mapping,
      dirty_map: dirty_map,
    )
  end
end

require "sequel_mapper/root_mapper"
