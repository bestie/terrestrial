require "forwardable"

module SequelMapper
  class AssociationProxy
    def initialize(assoc_enum)
      @assoc_enum = assoc_enum
      @added_nodes = []
      @removed_nodes = []
    end

    attr_reader :assoc_enum, :removed_nodes, :added_nodes
    private     :assoc_enum

    include Enumerable
    def each(&block)
      if block
        enum.each(&block)
        self
      else
        enum
      end
    end

    def remove(node)
      @removed_nodes.push(node)
      self
    end

    def push(node)
      @added_nodes.push(node)
    end

    def where(criteria)
      @assoc_enum.where(criteria)
      self
    end

    def loaded?
      !!@loaded
    end

    private

    def enum
      Enumerator.new do |yielder|
        mark_as_loaded

        assoc_enum.each do |element|
          yielder.yield(element) unless removed?(element)
        end

        @added_nodes.each do |node|
          yielder.yield(node)
        end
      end
    end

    def mark_as_loaded
      @loaded = true
    end

    def removed?(node)
      @removed_nodes.include?(node)
    end
  end
end
