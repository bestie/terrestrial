require "forwardable"

module SequelMapper
  class AbstractRecord
    extend Forwardable

    def initialize(namespace, identity, raw_data = {})
      @namespace = namespace
      @identity = identity
      @raw_data = raw_data
    end

    attr_reader :namespace, :identity

    attr_reader :raw_data
    private     :raw_data

    def_delegators :to_h, :fetch

    def if_upsert(&block)
      self
    end

    def if_delete(&block)
      self
    end

    def merge(more_data)
      new_with_raw_data(raw_data.merge(more_data))
    end

    def to_h
      raw_data.merge(identity)
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
