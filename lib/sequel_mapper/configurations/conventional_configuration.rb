require "sequel_mapper/configurations/conventional_association_configuration"
require "sequel_mapper/relation_mapping"
require "sequel_mapper/subset_queries_proxy"
require "sequel_mapper/struct_factory"

module SequelMapper
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

      def setup_mapping(mapping_name, &block)
        @associations_by_mapping[mapping_name] ||= []

        block.call(
          RelationConfigOptionsProxy.new(
            method(:add_override).to_proc.curry.call(mapping_name),
            method(:add_subset).to_proc.curry.call(mapping_name),
            @associations_by_mapping.fetch(mapping_name),
          )
        ) if block

        # TODO: more madness in this silly config this, kill it with fire.
        explicit_settings = @overrides[mapping_name] ||= {}
        explicit_settings[:factory] ||= raise_if_not_found_factory(mapping_name)

        self
      end

      private

      class RelationConfigOptionsProxy
        def initialize(config_override, subset_adder, association_register)
          @config_override = config_override
          @subset_adder = subset_adder
          @association_register = association_register
        end

        def relation_name(name)
          @config_override.call(relation_name: name)
        end
        alias_method :table_name, :relation_name

        def subset(subset_name, &block)
          @subset_adder.call(subset_name, block)
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

        def fields(field_names)
          @config_override.call(fields: field_names)
        end

        def factory(callable)
          @config_override.call(factory: callable)
        end

        def class(entity_class)
          @config_override.call('class': entity_class)
        end

        def class_name(class_name)
          @config_override.call(class_name: class_name)
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

      def add_subset(mapping_name, subset_name, block)
        @subset_queries.store(
          mapping_name,
          @subset_queries.fetch(mapping_name, {}).merge(
            subset_name => block,
          )
        )
      end

      def association_configurator(mappings, mapping_name)
        ConventionalAssociationConfiguration.new(
          mapping_name,
          mappings,
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
                  **default_mapping_args(table_name, mapping_name).merge(overrides)
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

      def default_mapping_args(table_name, mapping_name)
        {
          name: mapping_name,
          relation_name: table_name,
          fields: get_fields(table_name),
          primary_key: get_primary_key(table_name),
          factory: ok_if_it_doesnt_exist_factory(mapping_name),
          serializer: hash_coercion_serializer,
          associations: {},
          subsets: subset_queries_proxy(@subset_queries.fetch(mapping_name, {})),
        }
      end

      def overrides_for_table(table_name)
        mapping_name, overrides = @overrides
          .find { |(_mapping_name, config)|
            table_name == config.fetch(:relation_name, nil)
          } || [table_name, @overrides.fetch(table_name, {})]

        [mapping_name, consolidate_overrides(overrides)]
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

      def get_fields(table_name)
        datastore[table_name].columns
      end

      def get_primary_key(table_name)
        datastore.schema(table_name)
          .select { |field_name, properties|
            properties.fetch(:primary_key)
          }
          .map { |field_name, _| field_name }
      end

      def tables
        (datastore.tables - [:schema_migrations])
      end

      def hash_coercion_serializer
        ->(o) { o.to_h }
      end

      def subset_queries_proxy(subset_map)
        SubsetQueriesProxy.new(subset_map)
      end

      def mapping(name:, relation_name:, primary_key:, factory:, serializer:, fields:, associations:, subsets:)
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

      def raise_if_not_found_factory(name)
        ->(attrs) {
          class_to_factory(string_to_class(name)).call(attrs)
        }
      end

      def ok_if_it_doesnt_exist_factory(name)
        ->(attrs) {
          factory = class_to_factory(string_to_class(name)) rescue nil
          factory && factory.call(attrs)
        }
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

        Object.const_get(klass_name)
      end
    end
  end
end
