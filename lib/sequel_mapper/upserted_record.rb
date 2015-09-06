require "sequel_mapper/abstract_record"

module SequelMapper
  class UpsertedRecord < AbstractRecord
    def if_upsert(&block)
      block.call(self)
      self
    end

    protected
    def operation
      :upsert
    end
  end
end