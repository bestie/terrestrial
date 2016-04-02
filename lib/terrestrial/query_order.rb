module Terrestrial
  class QueryOrder
    def initialize(fields:, direction:)
      @fields = fields
      @direction_function = get_direction_function(direction.to_s.upcase)
    end

    attr_reader :fields, :direction_function

    def apply(dataset)
      if fields.any?
        apply_direction(dataset.order(fields))
      else
        dataset
      end
    end

    private

    def apply_direction(dataset)
      direction_function.call(dataset)
    end

    # TODO: Consider a nicer API for this and push this into SequelAdapter
    def get_direction_function(direction)
      {
        "ASC" => ->(x){x},
        "DESC" => :reverse.to_proc,
      }.fetch(direction) { raise "Unsupported sort option #{direction}. Choose one of [ASC, DESC]." }
    end
  end
end
