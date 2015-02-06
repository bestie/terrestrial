require "sequel_mapper/mapper_methods"

module SequelMapper
  class AbstractAssociationMapper
    include MapperMethods

    def initialize(relation:, proxy_factory:, dirty_map:, mappings:, mapping_name:)
      @relation = relation
      @proxy_factory = proxy_factory
      @dirty_map = dirty_map
      @mappings = mappings
      @mapping_name = mapping_name
      @eager_loads = {}
    end

    attr_reader :relation, :proxy_factory
    private :relation, :proxy_factory

    def inspect
      "\#<#{self.class.name}:#{self.object_id.<<(1).to_s(16)} " +
        inspectable_properties.map { |property|
          [
            property,
            instance_variable_get("@#{property}").inspect
          ].join("=")
        }
        .join(" ") + ">"
    end

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

    def eager_load(_values)
      raise NotImplementedError
    end

    private

    def mapping
      @mapping ||= @mappings.fetch(@mapping_name) { |name|
        raise "Mapping #{name} not found"
      }
    end

    def loaded?(object_or_collection)
      if object_or_collection.respond_to?(:loaded?)
        object_or_collection.loaded?
      else
        true
      end
    end

    def eagerly_loaded?(row)
      !!@eager_loads.fetch(row.fetch(key), false)
    end

    def inspectable_properties
      %w(
        relation
      )
    end
  end
end
