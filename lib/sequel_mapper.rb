module SequelMapper
  extend self

  def mapper(datastore:, top_level_namespace:, mappings:)
    Mapper.new(
      datastore: datastore,
      top_level_namespace: top_level_namespace,
      mappings: mappings,
    )
  end
end

require "sequel_mapper/mapper"
