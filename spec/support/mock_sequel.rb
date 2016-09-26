class Terrestrial::MockSequel
  def initialize(schema, storage = {})
    @schema = schema
    @relations = storage

    schema.each do |name, columns|
      @relations[name] = Relation.new(self, columns, [])
    end

    @reads, @updates, @inserts, @deletes = [], [], [], []
  end

  attr_reader :relations
  private     :relations

  def schema(table_name)
    @schema.fetch(table_name).map { |column_info|
      [
        column_info.fetch(:name),
        column_info.fetch(:options, { primary_key: false }),
      ]
    }
  end

  def tables
    @relations.keys
  end

  def rename_table(name, new_name)
    relations[new_name] = relations[name]
    relations.delete(name)
    @schema[new_name] = @schema[name]
    @schema.delete(name)
    self
  end

  def transaction(&block)
    old_state = Marshal.load(Marshal.dump(relations))
    block.call
  rescue Object => e
    rollback(old_state)
    raise e
  end

  def [](table_name)
    @relations.fetch(table_name)
  end

  def show_queries
    @reads + @updates + @inserts + @deletes
  end

  def log_read(query)
    @reads.push(dump(query))
  end

  def log_update(new_attrs)
    @updates.push(dump(new_attrs))
  end

  def log_insert(new_row)
    @inserts.push(dump(new_row))
  end

  def log_delete(row)
    @deletes.push(dump(row))
  end

  def read_count
    @reads.count
  end

  def reads
    @reads.map { |r| load(r) }
  end

  def updates
    @updates.map { |u| load(u) }
  end

  def update_count
    @updates.count
  end

  def write_count
    @updates.count + @inserts.count
  end

  def delete_count
    @deletes.count
  end

  private

  def rollback(relations)
    @relations = relations
  end

  def load(object)
    Marshal.load(object)
  end

  def dump(object)
    Marshal.dump(object)
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

    def initialize(database, schema, all_rows, selected_columns: nil, applied_query: Query.new)
      @database = database
      @schema = schema
      @all_rows = all_rows
      @applied_query = applied_query
      @selected_columns = selected_columns || all_column_names
    end

    attr_reader :schema
    attr_reader :database, :all_rows, :selected_columns, :applied_query
    private     :database, :all_rows, :selected_columns, :applied_query

    def columns
      all_column_names
    end

    def where(criteria, &block)
      new_with_query(Query.new(criteria: criteria, &block))
    end

    def select(*new_selected_columns)
      selected_columns = new_selected_columns & all_column_names
      self.class.new(database, columns, all_rows, selected_columns: selected_columns, applied_query: applied_query)
    end

    def order(*columns)
      new_with_query(applied_query.order(columns.flatten))
    end

    def reverse
      new_with_query(@applied_query.reverse)
    end

    def each(&block)
      database.log_read(applied_query)

      matching_rows.each(&block)
    end

    def delete
      matching_rows.each do |row_to_delete|
        database.log_delete(row_to_delete)
        all_rows.delete(row_to_delete)
      end
    end

    def insert(new_row)
      new_row_with_empty_fields = empty_row.merge(new_row)
      database.log_insert(new_row_with_empty_fields)

      all_rows.push(new_row_with_empty_fields)
    end

    def update(attrs)
      all_rows
        .select { |row| matching_rows.include?(row) }
        .each do |row|
          database.log_update([row, attrs])

          attrs.each do |k, v|
            row[k] = v
          end
        end
        .count
    end

    def empty?
      database.log_read(applied_query)

      matching_rows.empty?
    end

    protected

    def extract_values_for_sub_select(expected_columns: 1)
      unless selected_columns.size == expected_columns
        raise "Expected dataset with #{expected_columns} columns. Got #{selected_columns.size} columns."
      end

      matching_rows.flat_map(&:values)
    end

    private

    def matching_rows
      apply_sort(
        equality_filter(all_rows, applied_query.criteria),
        applied_query.order_columns,
        applied_query.reverse_order?,
      )
        .map { |row| row.select { |k, _v| selected_columns.include?(k) } }
        .map { |row| Marshal.load(Marshal.dump(row)) }
    end

    def apply_sort(rows, order_columns, reverse_order)
      sorted_rows = rows.sort_by{ |row|
        order_columns.map { |col| row.fetch(col) }
      }

      if reverse_order
        sorted_rows.reverse
      else
        sorted_rows
      end
    end

    def equality_filter(rows, criteria)
      rows.select { |row|
        criteria.all? { |k, v| match(row.fetch(k), v) }
      }
    end

    def match(value, comparitor)
      case comparitor
      when Relation
        comparitor.extract_values_for_sub_select.include?(value)
      when Enumerable
        comparitor.include?(value)
      when Regexp
        comparitor === value
      else
        comparitor == value
      end
    end

    def empty_row
      Hash[all_column_names.map { |name| [ name, nil ] }]
    end

    def all_column_names
      schema.map { |f| f.fetch(:name) }
    end

    def new_with_query(query)
      self.class.new(database, schema, all_rows, selected_columns: selected_columns, applied_query: query)
    end
  end
end
