require "forwardable"

module SequelMapper
  class AbstractRecord
    extend Forwardable

    def initialize(namespace, identity, attributes = {})
      @namespace = namespace
      @identity = identity
      @attributes = attributes
    end

    attr_reader :namespace, :identity, :attributes

    def_delegators :to_h, :fetch

    def if_upsert(&block)
      self
    end

    def if_delete(&block)
      self
    end

    def merge(more_data)
      new_with_raw_data(attributes.merge(more_data))
    end

    def reject(&block)
      new_with_raw_data(attributes.reject(&block))
    end

    def to_h
      attributes.merge(identity)
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
      self.class.new(namespace, identity, new_raw_data)
    end
  end
end
