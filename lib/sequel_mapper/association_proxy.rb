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
      enum = Enumerator.new do |yielder|
        assoc_enum.each do |element|
          yielder.yield(element) unless removed?(element)
        end

        @added_nodes.each do |node|
          yielder.yield(node)
        end
      end

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

    private

    def removed?(node)
      @removed_nodes.include?(node)
    end
  end
end
