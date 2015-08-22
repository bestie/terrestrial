require "sequel_mapper/namespaced_record"

module SequelMapper
  class DeletedRecord < NamespacedRecord
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
