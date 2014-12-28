module SequelMapper
  extend self

  def mapper(datastore:, top_level_namespace:, mappings:)
    Mapper.new(
      datastore: datastore,
      mapping: mappings[top_level_namespace],
    )
  end
end

require "sequel_mapper/mapper"
