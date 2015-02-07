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
        @associations_by_mapping = {}
      end

      attr_reader :datastore, :mappings
      private     :datastore, :mappings

      def [](mapping_name)
        mappings[mapping_name]
      end

      def setup_relation(table_name, &block)
        @associations_by_mapping[table_name] ||= []

        block.call(
          RelationConfigOptionsProxy.new(
            method(:add_override).to_proc.curry.call(table_name),
            @associations_by_mapping.fetch(table_name),
          )
        ) if block

        self
      end

      private

      require "forwardable"
      class RelationConfigOptionsProxy
        extend Forwardable
        def initialize(config_override, association_register)
          @config_override = config_override
          @association_register = association_register
        end

        def has_many(*args)
          @association_register.push([:has_many, args])
        end

        def has_many_through(*args)
          @association_register.push([:has_many_through, args])
        end

        def belongs_to(*args)
          @association_register.push([:belongs_to, args])
        end

        def factory(string_class_or_callable)
          @config_override.call(factory: string_class_or_callable)
        end
      end

      def mappings
        @mappings ||= generate_mappings
      end

      def add_override(mapping_name, attrs)
        overrides = @overrides.fetch(mapping_name, {}).merge(attrs)

        @overrides.store(mapping_name, overrides)
      end

      def assocition_configurator(mappings, table_name)
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
                  **mapping_args(table_name).merge(
                    overrides_for_mapping(table_name)
                  )
                ),
              ]
            }
        ].tap { |mappings|
          generate_associations_config(mappings)
        }
      end

      def generate_associations_config(mappings)
        # TODO: the ConventionalAssociationConfiguration takes all the mappings
        # as a dependency and then sends mutating messages to them.
        # This mutation based approach was originally a spike but now just
        # seems totally bananas!
        @associations_by_mapping.each do |mapping_name, associations|
          associations.each do |(assoc_type, assoc_args)|
            assocition_configurator(mappings, mapping_name)
              .public_send(assoc_type, *assoc_args)
          end
        end
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
