module Terrestrial
  module InspectionString
    def inspect
      original_inspect_string = super
      # this is kind of a silly way of getting the object id hex string but
      # multiple Ruby versions have changed how this calculated.
      hex_object_id = /#{self.class.to_s}:0x([0-9a-f]+)/.match(original_inspect_string)[1]

      (
        ["\#<#{self.class.to_s}:0x#{hex_object_id}"] +
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
