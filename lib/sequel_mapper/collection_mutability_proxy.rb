require "forwardable"
require "short_inspection_string"

module SequelMapper
  class CollectionMutabilityProxy
    include ShortInspectionString

    def initialize(collection)
      @collection = collection
      @added_nodes = []
      @deleted_nodes = []
    end

    attr_reader :collection, :deleted_nodes, :added_nodes
    private     :collection, :deleted_nodes, :added_nodes

    extend Forwardable
    def_delegators :collection, :loaded?, :where, :query

    def each_loaded(&block)
      if loaded?
        enum.each(&block)
      else
        added_nodes.each(&block)
      end
    end

    def each_deleted(&block)
      @deleted_nodes.each(&block)
    end

    include Enumerable
    def each(&block)
      if block
        enum.each(&block)
        self
      else
        enum
      end
    end

    def delete(node)
      @deleted_nodes.push(node)
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
          yielder.yield(element) unless deleted?(element)
        end

        added_nodes.each do |node|
          yielder.yield(node)
        end
      end
    end

    def deleted?(node)
      @deleted_nodes.include?(node)
    end
  end
end
