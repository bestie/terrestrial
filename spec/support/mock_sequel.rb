class SequelMapper::MockSequel
  def initialize(relations)
    @relations = relations
  end

  def [](table_name)
    Relation.new(@relations.fetch(table_name))
  end

  class Relation
    include Enumerable

    def initialize(rows)
      @rows = rows
    end

    def where(criteria, &block)
      if block
        raise NotImplementedError.new("Block filtering not implemented")
      end

      self.class.new(equality_filter(criteria))
    end

    def to_a
      @rows
    end

    def each(&block)
      to_a.each(&block)
    end

    private

    def equality_filter(criteria)
      @rows.select { |row|
        criteria.all? { |k, v|
          if v.is_a?(Enumerable)
            v.include?(row.fetch(k))
          else
            row.fetch(k) == v
          end
        }
      }
    end
  end
end
