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
        @mappings = generate_mappings
      end

      attr_reader :datastore, :mappings
      private     :datastore, :mappings

      def [](mapping_name)
        mappings[mapping_name]
      end

      def setup_relation(table_name, &block)
        block.call(assocition_configurator(table_name)) if block
        self
      end

      private

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
                  fields: get_fields(table_name),
                  factory: table_name_to_factory(table_name),
                  associations: {},
                ),
              ]
            }
          ]
      end

      def get_fields(table_name)
        datastore[table_name]
          .columns
      end

      def table_name_to_factory(table_name)
        klass_name = INFLECTOR.classify(table_name)

        if Object.constants.include?(klass_name.to_sym)
          klass = Object.const_get(klass_name)
          if klass.ancestors.include?(Struct)
            StructFactory.new(klass)
          else
            klass.method(:new)
          end
        else
          warn "WARNDING: Class not found for table #{table_name}"
        end
      end

      def tables
        (datastore.tables - [:schema_migrations])
      end

      def dirty_map
        DIRTY_MAP
      end

      def mapping(**args)
        IdentityMap.new(
          Mapping.new(**args)
        )
      end
    end
  end
end
