require "forwardable"
require "sequel_mapper/short_inspection_string"

module Terrestrial
  class CollectionMutabilityProxy
    extend Forwardable
    include ShortInspectionString
    include Enumerable

    def initialize(collection)
      @collection = collection
      @added_nodes = []
      @deleted_nodes = []
    end

    attr_reader :collection, :deleted_nodes, :added_nodes
    private     :collection, :deleted_nodes, :added_nodes

    def_delegators :collection, :where, :subset

    def each_loaded(&block)
      loaded_enum.each(&block)
    end

    def each_deleted(&block)
      @deleted_nodes.each(&block)
    end

    def to_ary
      to_a
    end

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

    private

    def loaded_enum
      Enumerator.new do |yielder|
        collection.each_loaded do |element|
          yielder.yield(element) unless deleted?(element)
        end

        added_nodes.each do |node|
          yielder.yield(node)
        end
      end
    end

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
