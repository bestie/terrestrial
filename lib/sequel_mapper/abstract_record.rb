require "forwardable"
require "set"

module SequelMapper
  class AbstractRecord
    extend Forwardable
    include Comparable
    include Enumerable

    def initialize(namespace, identity_fields, attributes = {}, depth = NoDepth)
      @namespace = namespace
      @identity_fields = identity_fields
      @attributes = attributes
      @depth = depth
    end

    attr_reader :namespace, :identity_fields, :attributes, :depth
    private :attributes

    def_delegators :to_h, :fetch

    def if_upsert(&block)
      self
    end

    def if_delete(&block)
      self
    end

    def each(&block)
      to_h.each(&block)
    end

    def keys
      attributes.keys
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

    def empty?
      non_identity_attributes.empty?
    end

    def ==(other)
      self.class === other &&
        [operation, to_h] == [other.operation, other.to_h]
    end

    def <=>(other)
      depth <=> other.depth
    end

    def subset?(other_record)
      namespace == other_record.namespace &&
        to_set.subset?(other_record.to_set)
    end

    protected

    def operation
      NoOp
    end

    def to_set
      Set.new(attributes.to_a)
    end

    private

    NoOp = Module.new
    NoDepth = Module.new

    def new_with_raw_data(new_raw_data)
      self.class.new(namespace, identity_fields, new_raw_data, depth)
    end
  end
end
