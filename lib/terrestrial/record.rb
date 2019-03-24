require "forwardable"
require "set"

module Terrestrial
  class Record
    extend Forwardable

    def initialize(mapping, attributes)
      @mapping = mapping
      @attributes = attributes
    end

    attr_reader :mapping, :attributes
    def_delegators :to_h, :fetch

    def namespace
      mapping.namespace
    end

    def if_upsert(&block)
      self
    end

    def if_delete(&block)
      self
    end

    def updatable?
      updatable_attributes.any?
    end

    def updatable_attributes
      attributes.reject { |k, _v| non_updatable_fields.include?(k) }
    end

    def keys
      attributes.keys
    end

    def identity_values
      identity.values
    end

    def identity
      attributes.select { |k,_v| identity_fields.include?(k) }
    end

    def identity_fields
      mapping.primary_key
    end

    def merge(more_attributes)
      new_with_attributes(attributes.merge(more_attributes))
    end

    def merge!(more_attributes)
      attributes.merge!(more_attributes)
    end

    def reject(&block)
      new_with_attributes(updatable_attributes.reject(&block).merge(identity))
    end

    def to_h
      attributes.to_h
    end

    def empty?
      updatable_attributes.empty?
    end

    def subset?(other_record)
      mapping == other_record.mapping &&
        to_set.subset?(other_record.to_set)
    end

    def deep_clone
      new_with_attributes(Marshal.load(Marshal.dump(attributes)))
    end

    def ==(other)
      other.is_a?(self.class) &&
        [other.mapping, other.attributes] == [mapping, attributes]
    end

    protected

    def to_set
      Set.new(attributes.to_a)
    end

    private

    def non_updatable_fields
      identity_fields + mapping.database_owned_fields + nil_fields_expecting_default_value
    end

    def nil_fields_expecting_default_value
      mapping.database_default_fields.select { |k| attributes[k].nil? }
    end

    def new_with_attributes(new_attributes)
      self.class.new(mapping, new_attributes)
    end
  end
end
