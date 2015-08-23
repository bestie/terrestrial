require "sequel_mapper/upserted_record"

module SequelMapper
  class DeletedRecord < UpsertedRecord
    def to_a
      [:delete, namespace, data]
    end

    def if_upsert(&block)
      self
    end

    def if_delete(&block)
      block.call(self)
      self
    end
  end
end
