module Terrestrial
  module ShortInspectionString
    def inspect
      "\#<#{self.class.name}:#{self.object_id.<<(1).to_s(16)} " +
        inspectable_properties.map { |property|
          [
            property,
            instance_variable_get("@#{property}").inspect
          ].join("=")
        }
        .join(" ") + ">"
    end

    def inspectable_properties
      []
    end
  end
end
