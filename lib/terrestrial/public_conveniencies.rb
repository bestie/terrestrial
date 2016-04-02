require "terrestrial/identity_map"
require "terrestrial/dirty_map"
require "terrestrial/upserted_record"
require "terrestrial/mapper_facade"
require "terrestrial/configurations/conventional_configuration"

module Terrestrial
  module PublicConveniencies
    def config(database_connection)
      Configurations::ConventionalConfiguration.new(database_connection)
    end

    def mappers(mappings:, datastore:)
      dirty_map = build_dirty_map
      identity_map = build_identity_map

      Hash[mappings.map { |name, _mapping|
        [
          name,
          mapper(
            mappings: mappings ,
            name: name,
            datastore: datastore,
            identity_map: identity_map,
            dirty_map: dirty_map,
          )
        ]
      }]
    end

    private

    def mapper(mappings:, name:, datastore:, identity_map:, dirty_map:)
      dataset = datastore[mappings.fetch(name).namespace]

      MapperFacade.new(
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

    private

    def build_identity_map(storage = {})
      IdentityMap.new(storage)
    end

    def build_dirty_map(storage = {})
      DirtyMap.new(storage)
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

            object = mapping.factory.call(attributes.merge(associated_fields))
            identity_map.call(mapping, record, object)
          },
        ].reduce(record) { |agg, operation|
          operation.call(agg)
        }
      }
    end

    def build_dump_pipeline(dirty_map:, transaction:, upsert:, delete:)
      ->(records) {
        [
          :uniq.to_proc,
          ->(rs) { rs.select { |r| dirty_map.dirty?(r) } },
          ->(rs) { rs.map { |r| dirty_map.reject_unchanged_fields(r) } },
          ->(rs) { rs.sort_by(&:depth) },
          ->(rs) {
            transaction.call {
              rs.each { |r|
                r.if_upsert(&upsert)
                 .if_delete(&delete)
              }
            }
          },
        ].reduce(records) { |agg, operation|
          operation.call(agg)
        }
      }
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
      row_count = 0
      unless record.non_identity_attributes.empty?
        row_count = datastore[record.namespace].
          where(record.identity).
          update(record.non_identity_attributes)
      end

      if row_count < 1
        row_count = datastore[record.namespace].insert(record.to_h)
      end

      row_count
    end

    def delete_record(datastore, record)
      datastore[record.namespace].where(record.identity).delete
    end
  end
end
