require "forwardable"

module SequelMapper
  class IdentityMap
    extend Forwardable
    def_delegators :mapping, :relation_name, :factory, :fields, :dump

    def initialize(mapping, identity_map = {})
      @mapping = mapping
      @identity_map = identity_map
    end

    attr_reader :mapping, :identity_map
    private     :mapping, :identity_map

    def load(row)
      ensure_loaded_once(row.fetch(:id)) {
        mapping.load(row)
      }
    end

    private

    def ensure_loaded_once(id, &block)
      identity_map.fetch(id) {
        identity_map.store(id, block.call)
      }
    end
  end
end
