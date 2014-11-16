class SequelMapper::MockSequel
  def initialize(relations)
    @relations = {}

    relations.each do |table_name|
      @relations[table_name] = Relation.new(self, [])
    end

    @reads, @writes, @deletes = 0, 0, 0
  end

  attr_reader :relations
  private     :relations

  def [](table_name)
    @relations.fetch(table_name)
  end

  def log_read
    @reads += 1
  end

  def log_write
    @writes += 1
  end

  def log_delete
    @deletes += 1
  end

  def read_count
    @reads
  end

  def write_count
    @writes
  end

  def delete_count
    @deletes
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

    def initialize(database, all_rows, applied_query: Query.new)
      @database = database
      @all_rows = all_rows
      @applied_query = applied_query
    end

    attr_reader :database, :all_rows, :applied_query
    private     :database, :all_rows, :applied_query

    def where(criteria, &block)
      query = Query.new(criteria: criteria, &block)
      self.class.new(all_rows, applied_query: query)
    end

    def order(columns)
      self.class.new(all_rows, applied_query: query)
    end

    def to_a
      database.log_read

      matching_rows
    end

    def each(&block)
      puts "iterating over #{matching_rows}"
      database.log_read

      matching_rows.each(&block)
    end

    def delete
      database.log_delete

      matching_rows.each do |row_to_delete|
        all_rows.delete(row_to_delete)
      end
    end

    def insert(new_row)
      database.log_write

      all_rows.push(new_row)
    end

    def update(attrs)
      database.log_write

      # No need to get the rows from the canonical relation as the hashes can
      # just be mutated in plaace.
      matching_rows.each do |row|
        attrs.each do |k, v|
          row[k] = v
        end
      end
    end

    def empty?
      database.log_read

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
