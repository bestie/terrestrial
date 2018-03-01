require "terrestrial/configurations/mapping_config_options_proxy"
require "terrestrial/configurations/conventional_association_configuration"
require "terrestrial/relation_mapping"
require "terrestrial/subset_queries_proxy"
require "terrestrial/struct_factory"

module Terrestrial
  module Configurations
    require "active_support/inflector"
    class Inflector
      include ActiveSupport::Inflector
    end

    INFLECTOR = Inflector.new

    require "fetchable"
    class ConventionalConfiguration
      include Fetchable

      def initialize(datastore)
        @datastore = datastore
        @overrides = {}
        @subset_queries = {}
        @associations_by_mapping = {}
      end

      attr_reader :datastore, :mappings
      private     :datastore, :mappings

      def [](mapping_name)
        mappings[mapping_name]
      end

      include Enumerable
      def each(&block)
        mappings.each(&block)
      end

      def setup_mapping(mapping_name, &block)
        @associations_by_mapping[mapping_name] ||= []
        @overrides[mapping_name] ||= {}

        block && block.call(
          MappingConfigOptionsProxy.new(self, mapping_name)
        )

        self
      end

      def mappings
        @mappings ||= generate_mappings
      end

      def add_override(mapping_name, attrs)
        overrides = @overrides.fetch(mapping_name, {}).merge(attrs)

        @overrides.store(mapping_name, overrides)
      end

      def add_subset(mapping_name, subset_name, block)
        @subset_queries.store(
          mapping_name,
          @subset_queries.fetch(mapping_name, {}).merge(
            subset_name => block,
          )
        )
      end

      def add_assocation(mapping_name, type, options)
        @associations_by_mapping.fetch(mapping_name).push([type, options])
      end

      private

      def association_configurator(mappings, mapping_name)
        ConventionalAssociationConfiguration.new(
          mapping_name,
          mappings,
          datastore,
        )
      end

      def generate_mappings
        custom_mappings = @overrides.map { |mapping_name, overrides|
          [mapping_name, {relation_name: mapping_name}.merge(consolidate_overrides(overrides))]
        }

        table_mappings = (tables - @overrides.keys).map { |table_name|
          [table_name, overrides_for_table(table_name)]
        }

        Hash[
          (table_mappings + custom_mappings).map { |(mapping_name, overrides)|
            table_name = overrides.fetch(:relation_name) { raise no_table_error(mapping_name) }

            [
              mapping_name,
              build_mapping(
                **default_mapping_args(table_name, mapping_name).merge(overrides)
              ),
            ]
          }
        ]
        .tap { |mappings|
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

      def default_mapping_args(table_name, mapping_name)
        {
          name: mapping_name,
          relation_name: table_name,
          fields: all_available_fields(table_name),
          primary_key: get_primary_key(table_name),
          factory: ok_if_class_is_not_defined_factory(mapping_name),
          serializer: hash_coercion_serializer,
          associations: {},
          subsets: subset_queries_proxy(@subset_queries.fetch(mapping_name, {})),
        }
      end

      def overrides_for_table(table_name)
        overrides = @overrides.values.detect { |config|
          table_name == config.fetch(:relation_name, nil)
        } || {}

        { relation_name: table_name }.merge(
          consolidate_overrides(overrides)
        )
      end

      def consolidate_overrides(opts)
        new_opts = opts.dup

        if new_opts.has_key?(:class_name)
          new_opts.merge!(factory: string_to_factory(new_opts.fetch(:class_name)))
          new_opts.delete(:class_name)
        end

        if new_opts.has_key?(:class)
          new_opts.merge!(factory: class_to_factory(new_opts.fetch(:class)))
          new_opts.delete(:class)
        end

        new_opts
      end

      def all_available_fields(table_name)
        datastore[table_name].columns
      end

      def get_primary_key(table_name)
        datastore.schema(table_name)
          .select { |field_name, properties|
            properties.fetch(:primary_key, false)
          }
          .map { |field_name, _| field_name }
      end

      def tables
        (datastore.tables - [:schema_migrations])
      end

      def hash_coercion_serializer
        HashCoercionSerializer.new
      end

      def subset_queries_proxy(subset_map)
        SubsetQueriesProxy.new(subset_map)
      end

      def build_mapping(name:, relation_name:, primary_key:, factory:, serializer:, fields:, associations:, subsets:)
        RelationMapping.new(
          name: name,
          namespace: relation_name,
          primary_key: primary_key,
          factory: factory,
          serializer: serializer,
          fields: fields,
          associations: associations,
          subsets: subsets,
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

      TableNameNotSpecifiedError = Class.new(StandardError) do
        def initialize(mapping_name)
          @message = "Error defining custom mapping `#{mapping_name}`." +
            " You must provide the `table_name` configuration option."
        end
      end

      def class_with_same_name_as_mapping_factory(name)
        target_class = string_to_class(name)
        ClassFactory.new(target_class)
      end

      def ok_if_class_is_not_defined_factory(name)
        LazyClassLookupFactory.new(class_name(name))
      end

      def class_to_factory(klass)
        if klass.ancestors.include?(Struct)
          StructFactory.new(klass)
        else
          klass.method(:new)
        end
      end

      def string_to_class(string)
        Object.const_get(class_name(string))
      end

      def class_name(name)
        INFLECTOR.classify(name)
      end

      def no_table_error(table_name)
        TableNameNotSpecifiedError.new(table_name)
      end

      class ClassFactory
        def initialize(target_class)
          @target_class = target_class
        end

        def call(attrs)
          @target_class.new(attrs)
        end
      end

      class LazyClassLookupFactory
        def initialize(class_name)
          @class_name = class_name
        end

        def call(attrs)
          target_class && target_class.new(attrs)
        end

        private

        def target_class
          @target_class ||= Object.const_get(@class_name)
        end
      end

      class HashCoercionSerializer
        def call(object)
          object.to_h
        end
      end
    end
  end
end
