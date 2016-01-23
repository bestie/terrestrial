module SequelMapper
  class Dataset
    def initialize(records)
      @records = records
    end

    attr_reader :records
    private     :records

    include Enumerable

    def each(&block)
      records.each(&block)
      self
    end

    def where(criteria)
      new(
        records.find_all { |row|
          criteria.all? { |k, v|
            if v.respond_to?(:include?)
              test_inclusion_in_value(row, k, v)
            else
              test_equality(row, k, v)
            end
          }
        }
      )
    end

    def select(field)
      map { |data| data.fetch(field) }
    end

    private

    def new(records)
      self.class.new(records)
    end

    def test_inclusion_in_value(row, field, values)
      values.include?(row.fetch(field))
    end

    def test_equality(row, field, value)
      value == row.fetch(field)
    end
  end
end
