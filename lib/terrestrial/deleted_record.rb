require "terrestrial/abstract_record"

module Terrestrial
  class DeletedRecord < AbstractRecord
    def if_delete(&block)
      block.call(self)
      self
    end

    def subset?(_other)
      false
    end

    protected

    def operation
      :delete
    end
  end
end
