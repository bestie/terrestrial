module Terrestrial
  module Error
    attr_accessor :unfiltered_backtrace

    def filter_bactrace(trace)
      @unfiltered_backtrace = trace

      gem_paths = ENV.fetch("GEM_HOME", "").split(":")
      exclude_terrestial = !!ENV.fetch("TERRESTRIAL_FILTER_FROM_BACKTRACES", false)
      puts "exclude_terrestial = #{exclude_terrestial}"
      exclude_paths = gem_paths + (exclude_terrestial ? ["/terrestrial/"] : [])

      trace.reject { |line|
        exclude_paths.any? { |path| line.include?(path) }
      }
    end
  end

  class UpsertError < RuntimeError
    include Error

    def initialize(relation_name, record, original_error)
      @relation_name = relation_name
      @record = record
      @original_error = original_error

      set_backtrace(original_error.backtrace)
    end

    attr_reader :relation_name, :record, :original_error
    private :relation_name, :record, :original_error

    def message
      [
        "Error upserting record into `#{relation_name}` with data `#{record.inspect}`.",
        "",
        "Caught error:",
        "#{original_error.class.name} #{original_error.message}",
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

      set_backtrace(original_error.backtrace)
    end

    attr_reader :relation_name, :factory, :record, :original_error
    private :relation_name, :factory, :record, :original_error

    def message
      [
        "Error loading record from `#{relation_name}` relation `#{record.inspect}`.",
        "Using: `#{factory.inspect}`.",
        "Check that the factory is compatible.",
        "",
        "Caught error:",
        "#{original_error.class.name} #{original_error.message}",
      ].join("\n")
    end
  end

  class SerializationError < RuntimeError
    include Error

    def initialize(mapping_name, serializer, object, required_fields, original_error)
      @mapping_name = mapping_name
      @serializer = serializer
      @object = object
      @required_fields = required_fields
      @original_error = original_error

      set_backtrace(original_error.backtrace)
    end

    attr_reader :mapping_name, :serializer, :object, :required_fields, :original_error
    private :mapping_name, :serializer, :object, :required_fields, :original_error

    def message
      <<~MESSAGE
        #{original_error.class.name} #{original_error.message}

        Terrestrial couldn't serialize object `#{object.inspect}`.
        Terrestrial attempted to serialize it as part of mapping `#{mapping_name}` with `#{serializer.inspect}`.

        Suggested actions:

          - Check that mapping `#{mapping_name}` is supposed to handle objects with class `#{object.class}`.
            If not you may have put an object in the wrong field e.g. `user.apples = oranges`.

        #{serializer_suggestion}

        Serialzation is where Terrestrial attempts to convert your object into a hash of database-friendly values before writing them to the database.
        A typical serialzer will take a domain object and return a hash with a key for each column of the database table.
      MESSAGE
    end

    private

    def serializer_suggestion
      if default_serialier?
        default_serialier_suggestion
      else
        user_defined_serializer_suggestion
      end
    end

    def default_serialier_suggestion
      [
        "  - You are using Terrestrial's default serializer ensure the `#to_h` method on your object is returning all required fields:",
        "    `#{required_fields.inspect}`",
        "",
        "    The following implemenation may work for your object fields are the same as the database:",
        suggested_to_h_method_template,
      ].join("\n")
    end

    def user_defined_serializer_suggestion
      [
        "  - Check that the serializer returns a hash-like object with following keys:",
        "    `#{required_fields.inspect}`",
      ].join("\n")
    end

    def default_serialier?
      # TODO:maybe don't nest these so deeply
      serializer.is_a?(Terrestrial::Configurations::ConventionalConfiguration::HashCoercionSerializer)
    end

    def suggested_to_h_method_template
      hash_kv_list = required_fields.map { |f| "#{f}: #{f}" }.join(",\n    ")

      <<~RUBBY.split("\n").map { |l| (" " * 4) + l }.join("\n")
        ```
        def to_h
          {
            #{hash_kv_list}
          }
        end
        ```
        RUBBY
    end
  end
end
