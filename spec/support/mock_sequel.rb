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
    def initialize(criteria: {}, order: [], reverse: false, &block)
      if block
        raise NotImplementedError.new("Block filtering not implemented")
      end

      @criteria = criteria
      @order_columns = order
      @reverse_order = reverse
    end

    attr_reader :criteria, :order_columns

    def where(new_criteria, &block)
      self.class.new(
        criteria: criteria.merge(new_criteria),
        order: order,
        reverse: reverse,
        &block
      )
    end

    def order(columns)
      self.class.new(
        criteria: criteria,
        order: columns,
      )
    end

    def reverse
      self.class.new(
        criteria: criteria,
        order: order_columns,
        reverse: true,
      )
    end

    def reverse_order?
      !!@reverse_order
    end
  end

  class Relation
    include Enumerable

    def initialize(all_rows, applied_query: Query.new)
      @all_rows = all_rows
      @applied_query = applied_query
    end

    attr_reader :all_rows, :applied_query
    private     :all_rows, :applied_query

    def where(criteria, &block)
      query = Query.new(criteria: criteria, &block)
      self.class.new(all_rows, applied_query: query)
    end

    def order(columns)
      self.class.new(all_rows, applied_query: query)
    end

    def to_a
      matching_rows
    end

    def each(&block)
      matching_rows.each(&block)
    end

    def delete
      matching_rows.each do |row_to_delete|
        all_rows.delete(row_to_delete)
      end
    end

    def insert(new_row)
      all_rows.push(new_row)
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

    def empty?
      matching_rows.empty?
    end

    private

    def matching_rows
      apply_sort(
        equality_filter(all_rows, applied_query.criteria),
        applied_query.order_columns,
        applied_query.reverse_order?,
      )
    end

    def apply_sort(rows, order_columns, reverse_order)
      rows
      sorted_rows = rows.sort_by{ |row|
        order_columns.map { |col| row.fetch(col) }
      }

      reverse_order ? sorted_rows.reverse : sorted_rows
    end

    def equality_filter(rows, criteria)
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
