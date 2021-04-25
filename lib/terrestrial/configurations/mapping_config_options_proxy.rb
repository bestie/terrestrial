module Terrestrial
  module Configurations
    class MappingConfigOptionsProxy
      def initialize(configuration, mapping_name)
        @configuration = configuration
        @mapping_name = mapping_name
      end

      attr_reader :configuration, :mapping_name
      private :configuration, :mapping_name

      def relation_name(name)
        add_override(relation_name: name)
      end
      alias_method :table_name, :relation_name

      def subset(subset_name, &block)
        configuration.add_subset(mapping_name, subset_name, block)
      end

      def has_many(*args)
        add_association(:has_many, args)
      end

      def has_many_through(*args)
        add_association(:has_many_through, args)
      end

      def belongs_to(*args)
        add_association(:belongs_to, args)
      end

      def fields(field_names)
        add_override(fields: field_names)
      end

      def primary_key(field_names)
        add_override(primary_key: field_names)
      end

      def use_database_id(&block)
        add_override(use_database_id: true)
        block && add_override(database_id_setter: block)
      end

      def database_owned_field(field_name, &object_setter)
        configuration.overrides.fetch(mapping_name)[:database_owned_fields_setter_map] ||= {}
        db_owned_fields = configuration.overrides.fetch(mapping_name).fetch(:database_owned_fields_setter_map)

        db_owned_fields.merge!({field_name => object_setter})
      end

      def database_default_field(field_name, &object_setter)
        configuration.overrides.fetch(mapping_name)[:database_default_fields_setter_map] ||= {}
        db_default_fields = configuration.overrides.fetch(mapping_name).fetch(:database_default_fields_setter_map)

        db_default_fields.merge!({field_name => object_setter})
      end

      def created_at_timestamp(field_name = Default, &block)
        add_override(created_at_field: field_name)
        block && add_override(created_at_setter: block)
      end

      def updated_at_timestamp(field_name = Default, &block)
        add_override(updated_at_field: field_name)
        block && add_override(updated_at_setter: block)
      end

      def factory(callable)
        add_override(factory: callable)
      end

      def class(entity_class)
        add_override('class': entity_class)
      end

      def class_name(class_name)
        add_override(class_name: class_name)
      end

      def serializer(serializer_func)
        add_override(serializer: serializer_func)
      end

      private

      def add_override(*args)
        configuration.add_override(mapping_name, *args)
      end

      def add_association(*args)
        configuration.add_association(mapping_name, *args)
      end
    end
  end
end
