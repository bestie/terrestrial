require "sequel_mapper/identity_map"
require "sequel_mapper/dirty_map"
require "sequel_mapper/upserted_record"
require "sequel_mapper/mapper_facade"
require "sequel_mapper/configurations/conventional_configuration"

module SequelMapper
  module PublicConveniencies
    def config(database_connection)
      Configurations::ConventionalConfiguration.new(database_connection)
    end

    def mapper(config:, name:, datastore:)
      dataset = datastore[config.fetch(name).namespace]
      identity_map = build_identity_map
      dirty_map = build_dirty_map

      MapperFacade.new(
        mappings: config,
        mapping_name: name,
        datastore: datastore,
        dataset: dataset,
        load_pipeline: build_load_pipeline(
          dirty_map: dirty_map,
          identity_map: identity_map,
        ),
        dump_pipeline: build_dump_pipeline(
          dirty_map: dirty_map,
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
      ->(mapping, record, other_attrs = {}) {
        [
          record_factory(mapping),
          dirty_map.method(:load),
          ->(r) { identity_map.call(r, mapping.factory.call(r.merge(other_attrs))) },
        ].reduce(record) { |agg, operation|
          operation.call(agg)
        }
      }
    end

    def build_dump_pipeline(dirty_map:, upsert:, delete:)
      ->(records) {
        [
          :uniq.to_proc,
          ->(rs) { rs.select { |r| dirty_map.dirty?(r) } },
          ->(rs) { rs.map { |r| dirty_map.reject_unchanged_fields(r) } },
          ->(rs) {
            rs.each { |r|
              r.if_upsert(&upsert)
               .if_delete(&delete)
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
      row_count = datastore[record.namespace]
        .where(record.identity)
        .update(record.attributes)

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
