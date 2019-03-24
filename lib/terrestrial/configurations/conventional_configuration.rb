require "fetchable"

require "terrestrial/configurations/mapping_config_options_proxy"
require "terrestrial/configurations/conventional_association_configuration"
require "terrestrial/relation_mapping"
require "terrestrial/subset_queries_proxy"
require "terrestrial/struct_factory"
require "sequel/model/inflections"

module Terrestrial
  module Configurations

    class Inflector
      include Sequel::Inflections

      def classify(string)
        singularize(camelize(string))
      end

      public :singularize
      public :pluralize
    end

    Default = Module.new

    class ConventionalConfiguration
      include Enumerable
      include Fetchable

      def initialize(datastore, clock: Time, inflector: Inflector.new)
        @datastore = datastore
        @inflector = inflector
        @clock = clock
        @overrides = {}
        @subset_queries = {}
        @associations_by_mapping = {}
        @clock = clock
      end

      attr_reader :overrides
      attr_reader :datastore, :mappings, :inflector, :clock
      private     :datastore, :mappings, :inflector, :clock

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

      # TODO: typo
      def add_assocation(mapping_name, type, options)
        @associations_by_mapping.fetch(mapping_name).push([type, options])
      end

      private

      def association_configurator(mappings, mapping_name)
        ConventionalAssociationConfiguration.new(
          inflector,
          datastore,
          mapping_name,
          mappings,
        )
      end

      def generate_mappings
        custom_mappings = @overrides.map { |mapping_name, overrides|
          [mapping_name, {relation_name: mapping_name}.merge(consolidate_overrides(overrides))]
        }

        Hash[
          (custom_mappings).map { |(mapping_name, overrides)|
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
        @associations_by_mapping.each do |mapping_name, association_data|
          association_data.each do |(assoc_type, assoc_args)|
            association = association_configurator(mappings, mapping_name)
              .public_send(assoc_type, *assoc_args)

            name = assoc_args.fetch(0)
            mappings.fetch(mapping_name).add_association(name, association)
          end
        end
      end

      def default_mapping_args(table_name, mapping_name)
        {
          name: mapping_name,
          relation_name: table_name,
          fields: all_available_fields(table_name),
          primary_key: get_primary_key(table_name),
          use_database_id: false,
          database_id_setter: nil,
          database_owned_fields_setter_map: {},
          database_default_fields_setter_map: {},
          updated_at_field: nil,
          updated_at_setter: nil,
          created_at_field: nil,
          created_at_setter: nil,
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

      def all_available_fields(relation_name)
        datastore.relation_fields(relation_name)
      end

      def get_primary_key(table_name)
        datastore.schema(table_name)
          .select { |field_name, properties|
            properties.fetch(:primary_key, false)
          }
          .map { |field_name, _| field_name }
      end

      # TODO: inconsisent naming
      def tables
        datastore.relations
      end

      def hash_coercion_serializer
        HashCoercionSerializer.new
      end

      def subset_queries_proxy(subset_map)
        SubsetQueriesProxy.new(subset_map)
      end

      def build_mapping(name:, relation_name:, primary_key:, use_database_id:, database_id_setter:, database_owned_fields_setter_map:, database_default_fields_setter_map:, updated_at_field:, updated_at_setter:, created_at_field:, created_at_setter:, factory:, serializer:, fields:, associations:, subsets:)
        if use_database_id
          database_id_setter ||= object_setter(primary_key.first)
        end
        if created_at_field
          created_at_field = created_at_field == Default ? :created_at : created_at_field
          created_at_setter ||= object_setter(created_at_field)
        end
        if updated_at_field
          updated_at_field = updated_at_field == Default ? :updated_at : updated_at_field
          updated_at_setter ||= object_setter(updated_at_field)
        end

        timestamp_observer = TimestampObserver.new(
          clock,
          created_at_field,
          created_at_setter,
          updated_at_field,
          updated_at_setter,
        )

        database_owned_field_observers = database_owned_fields_setter_map.map { |field, setter|
          setter ||= ->(object, value) { object.send("#{field}=", value) }
          ArbitraryDatabaseOwnedValueObserver.new(field, setter)
        }

        database_default_field_observers = database_default_fields_setter_map.map { |field, setter|
          setter ||= ->(object, value) { object.send("#{field}=", value) }
          ArbitraryDatabaseDefaultValueObserver.new(field, setter)
        }

        observers = [
          use_database_id && DatabaseIDObserver.new(database_id_setter),
          (created_at_field || updated_at_field) && timestamp_observer,
          *database_owned_field_observers,
          *database_default_field_observers,
        ].select(&:itself)

        RelationMapping.new(
          name: name,
          namespace: relation_name,
          primary_key: primary_key,
          factory: factory,
          serializer: serializer,
          fields: fields,
          database_owned_fields: database_owned_fields_setter_map.keys,
          database_default_fields: database_default_fields_setter_map.keys,
          associations: associations,
          subsets: subsets,
          observers: observers,
        )
      end

      def object_setter(field_name)
        SetterMethodCaller.new(field_name)
      end

      def simple_setter_method_caller(primary_key)
        SetterMethodCaller.new(primary_key.first)
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
        inflector.classify(name)
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

      class TableNameNotSpecifiedError < StandardError
        def initialize(mapping_name)
          @message = "Error defining custom mapping `#{mapping_name}`." \
            " You must provide the `table_name` configuration option."
        end
      end

      class DatabaseIDObserver
        def initialize(setter)
          @setter = setter
        end

        attr_reader :setter
        private :setter

        def post_serialize(mapping, object, record)
          add_database_id_container!(record)
        end

        def post_save(mapping, object, record, new_record)
          if !record.id?
            new_id = new_record.identity_values.first
            record.identity_values.first.value = new_id
            setter.call(object, new_id)
          end
        end

        private

        def add_database_id_container!(record)
          if !record.id?
            record.set_id(database_id_container)
          end
        end

        def database_id_container
          Terrestrial::DatabaseID.new
        end
      end

      # TODO: It is very tempting to implement database generated IDs in terms of this
      class ArbitraryDatabaseOwnedValueObserver
        def initialize(field_name, setter)
          @field_name = field_name
          @setter = setter
        end

        attr_reader :field_name, :setter
        private :field_name, :setter

        def post_serialize(*_args)
        end

        def post_save(mapping, object, record, new_record)
          setter.call(object, new_record.get(field_name))
        end
      end

      class ArbitraryDatabaseDefaultValueObserver
        def initialize(field_name, setter)
          @field_name = field_name
          @setter = setter
        end

        attr_reader :field_name, :setter
        private :field_name, :setter

        def post_serialize(*_args)
        end

        def post_save(mapping, object, record, new_record)
          if value_changed?(new_record, record)
            setter.call(object, new_record.get(field_name))
          end
        end

        private

        def value_changed?(new_record, old_record)
          new_record.attributes[field_name] != old_record.attributes[field_name]
        end
      end

      class TimestampObserver
        def initialize(clock, created_at_field, created_at_setter, updated_at_field, updated_at_setter)
          @clock = clock
          @created_at_field = created_at_field
          @created_at_setter = created_at_setter
          @updated_at_field = updated_at_field
          @updated_at_setter = updated_at_setter
          @setter = setter
        end

        attr_reader :clock, :created_at_field, :updated_at_field, :created_at_setter, :updated_at_setter, :setter
        private     :clock, :created_at_field, :updated_at_field, :created_at_setter, :updated_at_setter, :setter

        def post_serialize(mapping, object, record)
          time = clock.now

          if created_at_field && !record.get(created_at_field)
            record.set(created_at_field, time)
          end

          if updated_at_field
            record.set(updated_at_field, time)
          end
        end

        def post_save(mapping, object, record, new_record)
          if created_at_field && record.fetch(created_at_field, false)
            time = record.fetch(created_at_field)
            created_at_setter.call(object, time)
          end

          if updated_at_field
            time = record.get(updated_at_field)
            updated_at_setter.call(object, time)
          end
        end
      end

      class SetterMethodCaller
        def initialize(field_name)
          raise "hell no" unless field_name
          @setter_method = "#{field_name}="
        end

        def call(object, value)
          object.public_send(@setter_method, value)
        end
      end
    end
  end
end
