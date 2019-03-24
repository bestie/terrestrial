require "terrestrial/identity_map"
require "terrestrial/dirty_map"
require "terrestrial/upsert_record"
require "terrestrial/relational_store"
require "terrestrial/configurations/conventional_configuration"
require "terrestrial/inspection_string"
require "terrestrial/functional_pipeline"
require "terrestrial/adapters/sequel_postgres_adapter"

module Terrestrial
  class ObjectStore
    include Fetchable
    include InspectionString

    def initialize(stores)
      @mappings = stores.keys
      @stores = stores
    end

    def [](mapping_name)
      @stores[mapping_name]
    end

    def from(mapping_name)
      fetch(mapping_name)
    end

    private

    def inspectable_properties
      [ :mappings ]
    end
  end

  module PublicConveniencies
    def config(database, clock: Time)
      Configurations::ConventionalConfiguration.new(
        Private.datastore_adapter(database),
        clock: clock
      )
    end

    def object_store(config:)
      mappings = config.mappings
      clock = config.send(:clock)
      datastore = config.send(:datastore)

      dirty_map = Private.build_dirty_map
      identity_map = Private.build_identity_map
      mapping_names = mappings.keys
      load_pipeline = Private.build_load_pipeline(
        dirty_map: dirty_map,
        identity_map: identity_map,
      )
      dump_pipeline = Private.build_dump_pipeline(
        dirty_map: dirty_map,
        datastore: datastore,
        clock: clock,
      )

      stores = Hash[mapping_names.map { |mapping_name|
        [
          mapping_name,
          Private.relational_store(
            name: mapping_name,
            mappings: mappings ,
            datastore: datastore,
            identity_map: identity_map,
            dirty_map: dirty_map,
            load_pipeline: load_pipeline,
            dump_pipeline: dump_pipeline,
          )
        ]
      }]

      ObjectStore.new(stores)
    end

    module Private
      module_function

      def relational_store(mappings:, name:, datastore:, identity_map:, dirty_map:, load_pipeline:, dump_pipeline:)
        RelationalStore.new(
          mappings: mappings,
          mapping_name: name,
          datastore: datastore,
          load_pipeline: load_pipeline,
          dump_pipeline: dump_pipeline,
        )
      end

      def build_identity_map(storage = {})
        IdentityMap.new(storage)
      end

      def build_dirty_map(storage = {})
        DirtyMap.new(storage)
      end

      def datastore_adapter(datastore)
        if datastore.is_a?(Terrestrial::Adapters::AbstractAdapter)
          return datastore
        end

        case datastore.class.name
        when "Sequel::Postgres::Database"
          Adapters::SequelPostgresAdapter.new(datastore)
        else
          raise "No adapter found for #{datastore.inspect}"
        end
      end

      def build_load_pipeline(dirty_map:, identity_map:)
        ->(mapping, record, associated_fields = {}) {
          [
            ->(record) { Record.new(mapping, record) },
            dirty_map.method(:load),
            ->(record) {
              attributes = record.to_h.select { |k,_v|
                mapping.fields.include?(k)
              }

              object = mapping.load(attributes.merge(associated_fields))
              identity_map.call(mapping, record, object)
            },
          ].reduce(record) { |agg, operation|
              operation.call(agg)
            }
        }
      end

      def build_dump_pipeline(dirty_map:, datastore:, clock:)
        Terrestrial::FunctionalPipeline.from_array([
          [:dedup, :uniq.to_proc],
          [:sort_by_depth, ->(rs) { rs.sort_by(&:depth) }],
          [:select_changed, ->(rs) { rs.select { |r| dirty_map.dirty?(r) } }],
          [:remove_unchanged_fields, ->(rs) { rs.map { |r| dirty_map.reject_unchanged_fields(r) } }],
          [:save_records, ->(rs) {
            datastore.transaction {
                rs.each { |r|
                  r.if_upsert(&datastore.method(:upsert))
                  r.if_delete(&datastore.method(:delete))
                }
              }
            }
          ],
          [:add_new_records_to_dirty_map, ->(rs) { rs.map { |r| dirty_map.load_if_new(r) } }],
        ])
      end
   end
  end
end
