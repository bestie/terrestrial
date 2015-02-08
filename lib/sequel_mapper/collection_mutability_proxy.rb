require "forwardable"

module SequelMapper
  class CollectionMutabilityProxy
    def initialize(collection)
      @collection = collection
      @added_nodes = []
      @removed_nodes = []
    end

    attr_reader :collection, :removed_nodes, :added_nodes
    private     :collection

    extend Forwardable
    def_delegators :collection, :loaded?, :where, :query

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

    def eager_load(association_name)
      collection.eager_load(association_name)
    end

    private

    def enum
      Enumerator.new do |yielder|
        collection.each do |element|
          yielder.yield(element) unless removed?(element)
        end

        added_nodes.each do |node|
          yielder.yield(node)
        end
      end
    end

    def removed?(node)
      @removed_nodes.include?(node)
    end
  end
end
