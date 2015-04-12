require "forwardable"

module SequelMapper
  class NamespacedRecord
    extend Forwardable
    def initialize(namespace, record)
      @namespace, @record = namespace, record
    end

    attr_reader :namespace, :record

    def_delegators :record, :fetch

    def merge(hash)
      self.class.new(
        namespace,
        record.merge(hash),
      )
    end

    def each(&block)
      record.each(&block)
      self
    end

    def to_a
      [namespace, record]
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
