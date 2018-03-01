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
        add_assocation(:has_many, args)
      end

      def has_many_through(*args)
        add_assocation(:has_many_through, args)
      end

      def belongs_to(*args)
        add_assocation(:belongs_to, args)
      end

      def fields(field_names)
        add_override(fields: field_names)
      end

      def primary_key(field_names)
        add_override(primary_key: field_names)
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

      def add_assocation(*args)
        configuration.add_assocation(mapping_name, *args)
      end
    end
  end
end
