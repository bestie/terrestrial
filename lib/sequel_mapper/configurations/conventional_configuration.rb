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

    require "fetchable"
    class ConventionalConfiguration
      include Fetchable

      def initialize(datastore)
        @datastore = datastore
        @overrides = {}
        @queries = {}
        @associations_by_mapping = {}
      end

      attr_reader :datastore, :mappings
      private     :datastore, :mappings

      def [](mapping_name)
        mappings[mapping_name]
      end

      def setup_mapping(mapping_name, &block)
        @associations_by_mapping[mapping_name] ||= []

        block.call(
          RelationConfigOptionsProxy.new(
            method(:add_override).to_proc.curry.call(mapping_name),
            method(:add_query).to_proc.curry.call(mapping_name),
            @associations_by_mapping.fetch(mapping_name),
          )
        ) if block

        self
      end

      private

      require "forwardable"
      class RelationConfigOptionsProxy
        extend Forwardable
        def initialize(config_override, query_adder, association_register)
          @config_override = config_override
          @query_adder = query_adder
          @association_register = association_register
        end

        def relation_name(name)
          @config_override.call(relation_name: name)
        end
        alias_method :table_name, :relation_name

        def query(query_name, &block)
          @query_adder.call(query_name, block)
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

        def serializer(serializer_func)
          @config_override.call(serializer: serializer_func)
        end
      end

      def mappings
        @mappings ||= generate_mappings
      end

      def add_override(mapping_name, attrs)
        overrides = @overrides.fetch(mapping_name, {}).merge(attrs)

        @overrides.store(mapping_name, overrides)
      end

      def add_query(mapping_name, query_name, block)
        @queries.store(
          mapping_name,
          @queries.fetch(mapping_name, {}).merge(
            query_name => block,
          )
        )
      end

      def association_configurator(mappings, mapping_name)
        ConventionalAssociationConfiguration.new(
          mapping_name,
          mappings,
          dirty_map,
          datastore,
        )
      end

      def generate_mappings
        Hash[
          tables
            .map { |table_name|
              mapping_name, overrides = overrides_for_table(table_name)

              [
                mapping_name,
                mapping(
                  **mapping_args(table_name, mapping_name).merge(overrides)
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
            association_configurator(mappings, mapping_name)
              .public_send(assoc_type, *assoc_args)
          end
        end
      end

      def mapping_args(table_name, mapping_name)
        {
          relation_name: table_name,
          fields: get_fields(table_name),
          factory: ensure_factory(mapping_name),
          serializer: standard_serializer,
          associations: {},
          queries: @queries.fetch(mapping_name, {}),
        }
      end

      def overrides_for_table(table_name)
        @overrides.find { |(_mapping_name, config)|
          table_name == config.fetch(:relation_name, nil)
        } || [table_name, @overrides.fetch(table_name, {})]
      end

      def get_fields(table_name)
        datastore[table_name].columns
      end

      def tables
        (datastore.tables - [:schema_migrations])
      end

      def dirty_map
        DIRTY_MAP
      end

      def standard_serializer
        ->(fields, object) {
          Serializer.new(fields, object).to_h
        }
      end

      def mapping(relation_name: ,factory:, serializer:, fields:, associations:, queries:)
        IdentityMap.new(
          Mapping.new(
            relation_name: relation_name,
            factory: ensure_factory(factory),
            serializer: serializer,
            fields: fields,
            associations: associations,
            queries: queries,
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
