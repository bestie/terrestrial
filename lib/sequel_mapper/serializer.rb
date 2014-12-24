module SequelMapper
  class Serializer
    def initialize(field_names, object)
      @field_names = field_names
      @object = object
    end

    attr_reader :field_names, :object

    def to_h
      Hash[
        field_names.map { |field_name|
          [field_name, object.public_send(field_name)]
        }
      ]
    end
  end
end
