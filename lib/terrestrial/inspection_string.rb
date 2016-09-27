module Terrestrial
  module InspectionString
    def inspect
      (
        ["\#<#{self.class.name}:0x#{sprintf("%014x", (object_id.<<(1)))}"] +
        inspectable_properties.map { |name|
          [
            name,
            instance_variable_get("@#{name}").inspect
          ].join("=")
        }
      ).join(" ") + ">"
    end

    private def inspectable_properties
      []
    end
  end
end
