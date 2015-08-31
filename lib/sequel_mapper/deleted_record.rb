require "sequel_mapper/abstract_record"

module SequelMapper
  class DeletedRecord < AbstractRecord
    def if_delete(&block)
      block.call(self)
      self
    end

    protected

    def operation
      :delete
    end
  end
end
