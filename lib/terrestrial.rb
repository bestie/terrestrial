require "logger"
require "terrestrial/public_conveniencies"

module Terrestrial
  # TODO: whoa! wtf is this? why did i?
  extend PublicConveniencies

  LOGGER = Logger.new(STDERR)

  class DatabaseID
    def initialize(val = nil)
      @value = val
    end

    def sql_literal(_dataset)
      @value.nil? ? "NULL" : @value.to_s
    end

    def nil?
      @value.nil?
    end

    def value=(v)
      @value = v
    end

    def to_s
      inspect
    end

    def inspect
      "#<%{class_name}>:0x%{hex_object_id} @value=%{value}>" % {
        class_name: self.class.name,
        hex_object_id: object_id.<<(1).to_s(16),
        value: @value,
      }
    end
  end
end
