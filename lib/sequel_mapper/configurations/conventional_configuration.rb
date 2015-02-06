require "sequel_mapper/configurations/conventional_association_configuration"
require "sequel_mapper/identity_map"
require "sequel_mapper/mapping"

module SequelMapper
  module Configurations
    require "active_support/inflector"
    class Inflector
      include ActiveSupport::Inflector
    end

    INFLECTOR = Inflector.new
    DIRTY_MAP = {}

    class ConventionalConfiguration
      def initialize(datastore)
        @datastore = datastore
        @overrides = {}
      end

      attr_reader :datastore, :mappings
      private     :datastore, :mappings

      def [](mapping_name)
        mappings[mapping_name]
      end

      def setup_relation(table_name, &block)
        block.call(
          RelationConfigOptionsProxy.new(
            mappings[table_name],
            assocition_configurator(table_name),
          )
        ) if block

        self
      end

      def add_override(mapping_name, attrs)
        overrides = @manual_overrides.fetch(mapping_name, {}).merge(attrs)

        @manual_overrides.store(mapping_name, overrides)
      end

      private

      require "forwardable"
      class RelationConfigOptionsProxy
        extend Forwardable
        def initialize(configurator, association_configurator)
          @configurator = configurator
          @association_configurator = association_configurator
        end

        def_delegators(:@association_configurator,
          :has_many,
          :has_many_through,
          :belongs_to,
        )

        def factory(string_class_or_callable)
          @configurator.add_override(factory: string_class_or_callable)
        end
      end

      def mappings
        @mappings ||= generate_mappings
      end

      def assocition_configurator(table_name)
        ConventionalAssociationConfiguration.new(
          table_name,
          mappings,
          dirty_map,
          datastore,
        )
      end

      def generate_mappings
        Hash[
          tables
            .map { |table_name|
              [
                table_name,
                mapping(
                  **overrides_for_mapping(table_name).merge(
                    mapping_args(table_name)
                  )
                ),
              ]
            }
          ]
      end

      def mapping_args(table_name)
        {
          fields: get_fields(table_name),
          factory: ensure_factory(table_name),
          associations: {},
        }
      end

      def overrides_for_mapping(mapping_name)
        @overrides.fetch(mapping_name, {})
      end

      def get_fields(table_name)
        datastore[table_name]
          .columns
      end

      def tables
        (datastore.tables - [:schema_migrations])
      end

      def dirty_map
        DIRTY_MAP
      end

      def mapping(factory:, fields:, associations:)
        IdentityMap.new(
          Mapping.new(
            factory: ensure_factory(factory),
            fields: fields,
            associations: associations,
          )
        )
      end

      FactoryNotFoundError = Class.new(StandardError) do
        def initialize(specified)
          @specified = specified
        end

        def message
          "Could not find factory for #{@specified}"
        end
      end

      NotFoundFacotry = Class.new do
        def initialize(error)
          @error = error
        end

        def call(*args)
          raise @error
        end
      end

      def ensure_factory(factory_argument)
        case factory_argument
        when String
        when Symbol
          ensure_factory(string_to_class(factory_argument))
        when Struct
        when Class
          class_to_factory(factory_argument)
        else
          if factory_argument.respond_to?(:call)
            factory_argument
          else
            NotFoundFacotry.new(
              FactoryNotFoundError.new(factory_argument)
            )
          end
        end
      end

      def class_to_factory(klass)
        if klass.ancestors.include?(Struct)
          StructFactory.new(klass)
        else
          klass.method(:new)
        end
      end

      def string_to_class(string)
        klass_name = INFLECTOR.classify(string)

        if Object.constants.include?(klass_name.to_sym)
          Object.const_get(klass_name)
        else
          warn "WARNING: Class not found #{string}" unless defined?(:RSpec)
        end
      end
    end
  end
end
