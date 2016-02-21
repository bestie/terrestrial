require "forwardable"

module SequelMapper
  class AbstractRecord
    extend Forwardable

    def initialize(namespace, identity_fields, attributes = {})
      @namespace = namespace
      @identity_fields = identity_fields
      @attributes = attributes
    end

    attr_reader :namespace, :identity_fields, :attributes
    private :attributes

    def_delegators :to_h, :fetch

    def if_upsert(&block)
      self
    end

    def if_delete(&block)
      self
    end

    def identity
      attributes.select { |k,_v| identity_fields.include?(k) }
    end

    def non_identity_attributes
      attributes.reject { |k| identity.include?(k) }
    end

    def merge(more_data)
      new_with_raw_data(attributes.merge(more_data))
    end

    def merge!(more_data)
      attributes.merge!(more_data)
    end

    def reject(&block)
      new_with_raw_data(non_identity_attributes.reject(&block).merge(identity))
    end

    def to_h
      attributes.to_h
    end

    def ==(other)
      self.class === other &&
        [operation, to_h] == [other.operation, other.to_h]
    end

    protected

    def operation
      raise NotImplementedError
    end

    private

    def new_with_raw_data(new_raw_data)
      self.class.new(namespace, identity_fields, new_raw_data)
    end
  end
end
