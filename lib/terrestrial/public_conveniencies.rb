require "terrestrial/identity_map"
require "terrestrial/dirty_map"
require "terrestrial/upserted_record"
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
    def config(database_connection)
      Configurations::ConventionalConfiguration.new(database_connection)
    end

    def object_store(mappings:, datastore:)
      dirty_map = Private.build_dirty_map
      identity_map = Private.build_identity_map
      datastore_adapter = Private.datastore_adapter(datastore)

      stores = Hash[mappings.map { |name, _mapping|
        [
          name,
          Private.single_type_store(
            mappings: mappings ,
            name: name,
            datastore: datastore_adapter,
            identity_map: identity_map,
            dirty_map: dirty_map,
          )
        ]
      }]

      ObjectStore.new(stores)
    end

    module Private
      module_function

      def single_type_store(mappings:, name:, datastore:, identity_map:, dirty_map:)
        dataset = datastore[mappings.fetch(name).namespace]

        RelationalStore.new(
          mappings: mappings,
          mapping_name: name,
          datastore: datastore,
          dataset: dataset,
          load_pipeline: build_load_pipeline(
            dirty_map: dirty_map,
            identity_map: identity_map,
          ),
          dump_pipeline: build_dump_pipeline(
            dirty_map: dirty_map,
            transaction: datastore.method(:transaction),
            upsert: method(:upsert_record).curry.call(datastore),
            delete: method(:delete_record).curry.call(datastore),
          )
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
            record_factory(mapping),
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

      def build_dump_pipeline(dirty_map:, transaction:, upsert:, delete:)
        Terrestrial::FunctionalPipeline.from_array([
          [:dedup, :uniq.to_proc],
          [:sort_by_depth, ->(rs) { rs.sort_by(&:depth) }],
          [:select_changed, ->(rs) { rs.select { |r| dirty_map.dirty?(r) } }],
          [:remove_unchanged_fields, ->(rs) { rs.map { |r| dirty_map.reject_unchanged_fields(r) } }],
          [:save_records, ->(rs) {
              transaction.call {
                rs.each { |r|
                  r.if_upsert(&upsert)
                  .if_delete(&delete)
                }
              }
            }
          ],
          [:add_new_records_to_dirty_map, ->(rs) { rs.map { |r| dirty_map.load_if_new(r) } }],
        ])
      end

      def record_factory(mapping)
        ->(record_hash) {
          identity = Hash[
            mapping.primary_key.map { |field|
              [field, record_hash.fetch(field)]
            }
          ]

          UpsertedRecord.new(
            mapping.namespace,
            identity,
            record_hash,
          )
        }
      end

      def upsert_record(datastore, record)
        datastore.upsert(record)
      end

      def delete_record(datastore, record)
        datastore[record.namespace].where(record.identity).delete
      end
    end
  end
end
