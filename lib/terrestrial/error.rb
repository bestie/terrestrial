module Terrestrial
  Error = Module.new

  class UpsertError < RuntimeError
    include Error

    def initialize(relation_name, record, original_error)
      @relation_name = relation_name
      @record = record
      @original_error = original_error
    end

    attr_reader :relation_name, :record, :original_error
    private :relation_name, :record, :original_error

    def message
      [
        "Error upserting record into `#{relation_name}` with data `#{record.inspect}`.",
        "Got Error: #{original_error.class.name} #{original_error.message}",
      ].join("\n")
    end
  end

  class LoadError < RuntimeError
    include Error

    def initialize(relation_name, factory, record, original_error)
      @relation_name = relation_name
      @factory = factory
      @record = record
      @original_error = original_error
    end

    attr_reader :relation_name, :factory, :record, :original_error
    private :relation_name, :factory, :record, :original_error

    def message
      [
        "Error loading record from `#{relation_name}` relation `#{record.inspect}`.",
        "Using: `#{factory.inspect}`.",
        "Check that the factory is compatible.",
        "Got Error: #{original_error.class.name} #{original_error.message}",
      ].join("\n")
    end
  end

  class SerializationError < RuntimeError
    include Error

    def initialize(relation_name, serializer, object, original_error)
      @relation_name = relation_name
      @serializer = serializer
      @object = object
      @original_error = original_error
    end

    attr_reader :relation_name, :serializer, :object, :original_error
    private :relation_name, :serializer, :object, :original_error

    def message
      [
        "Error serializing object with mapping `#{relation_name}` `#{object.inspect}`.",
        "Using serializer: `#{serializer.inspect}`.",
        "Check the specified serializer can transform objects into a Hash.",
        "Got Error: #{original_error.class.name} #{original_error.message}",
      ].join("\n")
    end
  end
end
