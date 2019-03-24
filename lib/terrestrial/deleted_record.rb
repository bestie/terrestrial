require "terrestrial/record"

module Terrestrial
  class DeletedRecord < Record
    def initialize(mapping, attributes, depth)
      @mapping = mapping
      @attributes = attributes
      @depth = depth
    end

    attr_reader :mapping, :attributes, :depth

    def if_delete(&block)
      block.call(self)
      self
    end

    protected

    def new_with_attributes(new_attributes)
      self.class.new(mapping, new_attributes, depth)
    end
  end
end
