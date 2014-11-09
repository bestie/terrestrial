class SequelMapper::MockSequel
  def initialize(relation_data)
    @relations = Hash[
      relation_data.map { |table_name, rows|
        [table_name, Relation.new(rows)]
      }
    ]
  end

  attr_reader :relations
  private     :relations

  def [](table_name)
    @relations.fetch(table_name)
  end

  class Query
    def initialize(criteria = {}, &block)
      if block
        raise NotImplementedError.new("Block filtering not implemented")
      end
      @criteria = criteria
    end

    attr_reader :criteria
  end

  class Relation
    include Enumerable

    def initialize(rows, applied_query: Query.new)
      @rows = rows
      @applied_query = applied_query
    end

    attr_reader :rows, :applied_query
    private     :rows, :applied_query

    def where(criteria, &block)
      query = Query.new(criteria, &block)
      self.class.new(rows, applied_query: query)
    end

    def to_a
      matching_rows
    end

    def each(&block)
      matching_rows.each(&block)
    end

    def delete
      matching_rows.each do |row_to_delete|
        rows.delete(row_to_delete)
      end
    end

    def insert(new_row)
      rows.push(new_row)
    end

    def update(attrs)
      # No need to get the rows from the canonical relation as the hashes can
      # just be mutated in plaace.
      matching_rows.each do |row|
        attrs.each do |k, v|
          row[k] = v
        end
      end
    end

    private

    def matching_rows
      equality_filter(applied_query.criteria)
    end

    def equality_filter(criteria)
      rows.select { |row|
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
