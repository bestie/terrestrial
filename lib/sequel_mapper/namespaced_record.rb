require "forwardable"

module SequelMapper
  class NamespacedRecord
    extend Forwardable
    def initialize(namespace, identity, data = {})
      @namespace = namespace
      @identity = identity
      @data = data
    end

    attr_reader :namespace, :identity

    def_delegators :data, :fetch, :to_h

    def if_upsert(&block)
      block.call(self)
      self
    end

    def if_delete(&block)
      self
    end

    def data
      @data.merge(identity)
    end

    def merge(hash)
      self.class.new(
        namespace,
        identity,
        data.merge(hash),
      )
    end

    def each(&block)
      data.each(&block)
      self
    end

    def to_a
      [:upsert, namespace, data]
    end

    def ==(other)
      other.is_a?(self.class) &&
        to_a == other.to_a
    end

    def eql?(other)
      self == other
    end

    def hash
      to_a.hash
    end
  end
end
