require "terrestrial/record"

module Terrestrial
  class UpsertRecord < Record
    def initialize(mapping, object, attributes, depth)
      @mapping = mapping
      @object = object
      @attributes = attributes
      @depth = depth
    end

    attr_reader :mapping, :object, :attributes, :depth

    def id?
      identity_values.reject(&:nil?).any?
    end

    def set_id(id)
      raise "Cannot use #set_id with composite key" if identity_fields.length > 1
      merge!(identity_fields[0] => id)
    end

    def get(name)
      fetch(name)
    end

    def set(name, value)
      merge!(name => value)
    end

    def if_upsert(&block)
      block.call(self)
      self
    end

    def on_upsert(new_attributes)
      mapping.post_save(object, self, new_attributes)
    end

    def insertable
      to_h.reject { |k, v| v.nil? && identity_fields.include?(k) }
    end

    def include?(field_name)
      keys.include?(field_name)
    end

    private

    def new_with_attributes(new_attributes)
      self.class.new(mapping, object, new_attributes, depth)
    end
  end
end
