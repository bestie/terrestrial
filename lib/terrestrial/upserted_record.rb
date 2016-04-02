require "terrestrial/abstract_record"

module Terrestrial
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
