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
        records.select { |row|
          criteria.all? { |k, v|
            row.fetch(k, :nope) == v
          }
        }
      )
    end

    private

    def new(records)
      self.class.new(records)
    end
  end
end
