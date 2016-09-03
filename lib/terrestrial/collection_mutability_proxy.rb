require "forwardable"
require "terrestrial/short_inspection_string"

module Terrestrial
  class CollectionMutabilityProxy
    extend Forwardable
    include ShortInspectionString
    include Enumerable

    def initialize(collection, added_nodes: [], deleted_nodes: [])
      @collection = collection
      @added_nodes = added_nodes
      @deleted_nodes = deleted_nodes
    end

    attr_reader :collection, :deleted_nodes, :added_nodes
    private     :collection, :deleted_nodes, :added_nodes

    def_delegators :collection, :where, :subset

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

    def push(node)
      force_load
      added_nodes.push(node)
      self
    end

    def delete(node)
      deleted_nodes.push(node)
      self
    end

    def _loaded_nodes
      loaded_enum.each
    end

    def _deleted_nodes
      deleted_nodes.each
    end

    def +(additional_nodes)
      force_load

      self.class.new(
        collection,
        added_nodes: added_nodes + additional_nodes,
        deleted_nodes: deleted_nodes.dup,
      )
    end

    def -(subtracted_nodes)
      self.class.new(
        collection,
        added_nodes: added_nodes.dup,
        deleted_nodes: deleted_nodes + subtracted_nodes,
      )
    end

    private

    def force_load
      to_a
    end

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
      deleted_nodes.include?(node)
    end
  end
end
