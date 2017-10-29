module Terrestrial
  module Adapters
  end
end

class Terrestrial::Adapters::MemoryAdapter
  def self.build_from_schema(schema, raw_storage)
    schema.each { |name, _| raw_storage[name] = [] }

    relations = Hash[schema.map { |name, columns|
      [name, Relation.new(columns, raw_storage.fetch(name))]
    }]

    new(schema, relations)
  end

  def initialize(schema, relations)
    @schema = schema
    @relations = relations
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

  private

  def rollback(relations)
    @relations = relations
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

    def initialize(schema, all_rows, selected_columns: nil, applied_query: Query.new)
      @schema = schema
      @all_rows = all_rows
      @applied_query = applied_query
      @selected_columns = selected_columns || all_column_names
    end

    attr_reader :schema
    attr_reader :all_rows, :selected_columns, :applied_query
    private     :all_rows, :selected_columns, :applied_query

    def columns
      all_column_names
    end

    def where(criteria, &block)
      new_with_query(Query.new(criteria: criteria, &block))
    end

    def select(*new_selected_columns)
      selected_columns = new_selected_columns & all_column_names
      self.class.new(columns, all_rows, selected_columns: selected_columns, applied_query: applied_query)
    end

    def order(*columns)
      new_with_query(applied_query.order(columns.flatten))
    end

    def reverse
      new_with_query(@applied_query.reverse)
    end

    def each(&block)
      matching_rows.each(&block)
    end

    def delete
      matching_rows.each do |row_to_delete|
        all_rows.delete(row_to_delete)
      end
    end

    def insert_conflict(target:, update: {})
      Upsert.new(self, target: target, update: update)
    end

    def insert(new_row)
      new_row_with_all_fields = empty_row.merge(clone(new_row))
      row_id = extract_row_id(new_row_with_all_fields)

      if row_id.any? && where(row_id).any?
        raise DuplicateKeyError.new(row_id)
      else
        all_rows.push(new_row_with_all_fields)
      end
    end

    def update(attrs)
      all_rows
        .select { |row| matching_rows.include?(row) }
        .each do |row|
          attrs.each do |k, v|
            row[clone(k)] = clone(v)
          end
        end
        .count
    end

    def empty?
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
      self.class.new(schema, all_rows, selected_columns: selected_columns, applied_query: query)
    end

    def clone(object)
      Marshal.load(Marshal.dump(object))
    end

    def extract_row_id(row)
      row.select { |k, _v| primary_key.include?(k) }
    end

    def primary_key
      @primary_key ||= schema
        .select { |col| col.fetch(:options, {}).fetch(:primary_key, nil) }
        .map { |col| col.fetch(:name) }
    end
  end

  # Small amount of code necessary to simulate upserts with Sequel's API
  class Upsert
    def initialize(dataset, target:, update:)
      @dataset = dataset
      @target = target
      @update_attributes = update
    end

    attr_reader :dataset, :target, :update_attributes
    private     :dataset, :target, :update_attributes

    def insert(row)
      dataset.insert(row)
    rescue DuplicateKeyError => e
      if target_matches?(e.key)
        attempt_update(e.row_id)
      end
    end

    def attempt_update(row_id)
      dataset.where(row_id).update(update_attributes)
    end

    def target_matches?(key)
      key.sort == Array(target).sort
    end
  end


  class DuplicateKeyError < RuntimeError
    def initialize(row_id)
      @row_id = row_id
    end

    attr_reader :row_id

    def key
      row_id.keys
    end

    def message
      "Insert conflict. Row with `#{row_id}` already exists"
    end
  end
end
