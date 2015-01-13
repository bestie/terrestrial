require "sequel_mapper/mapper_methods"

module SequelMapper
  class AbstractAssociationMapper
    include MapperMethods

    def initialize(datastore:, proxy_factory:, dirty_map:, mappings:, mapping_name:)
      @datastore = datastore
      @proxy_factory = proxy_factory
      @dirty_map = dirty_map
      @mappings = mappings
      @mapping_name = mapping_name
      @eager_loads = {}
    end

    attr_reader :datastore, :dirty_map, :proxy_factory
    private :datastore, :dirty_map, :proxy_factory

    def load_for_row(_row)
      raise NotImplementedError
    end

    def save(_source_object, _collection)
      raise NotImplementedError
    end

    def eager_load_association(_dataset, _association_name)
      raise NotImplementedError
    end

    def foreign_key_field(_label, _object)
      {}
    end

    def eager_load(_foreign_key_field, _values)
      raise NotImplementedError
    end

    private

    def mapping
      @mapping ||= @mappings.fetch(@mapping_name) { |name|
        raise "Mapping #{name} not found"
      }
    end

    def loaded?(collection)
      if collection.respond_to?(:loaded?)
        collection.loaded?
      else
        true
      end
    end

    def eagerly_loaded?(row)
      !!@eager_loads.fetch(row.fetch(key), false)
    end

    def association_by_name(name)
      mapping.fetch_association(name)
    end

    def row_loader_func
      ->(row) {
        dirty_map.store(row.fetch(:id), row)
        require "pry"; binding.pry if !mapping.is_a?(IdentityMap)
        mapping.load(row)
      }
    end
  end
end
