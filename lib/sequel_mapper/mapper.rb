require "sequel_mapper/namespaced_record"

module SequelMapper
  class Mapper
    def initialize(datastore:, mapping_name:, namespace:, primary_key:, serializer:, fields:, associations:, dataset:, mappers:)
      @datastore = datastore
      @mapping_name = mapping_name
      @namespace = namespace
      @primary_key = primary_key
      @serializer = serializer
      @fields = fields
      @associations = associations
      @dataset = dataset
      @mappers = mappers
    end

    attr_reader :datastore
    private     :datastore

    # For serialization
    attr_reader :mapping_name, :namespace, :primary_key, :serializer, :fields, :associations, :dataset, :mappers
    private     :mapping_name, :namespace, :primary_key, :serializer, :fields, :associations, :dataset, :mappers

    def save(graph)
      dump(graph).each do |record|
        upsert(namespace, record)
      end

      self
    end

    # TODO Move into another object, GraphSerializer perhaps
    def dump(object, foreign_key = {}, stack = [])
      serialized_record = serializer.call(object)

      current_record = NamespacedRecord.new(
        namespace,
        record_identity(serialized_record),
        serialized_record
          .select { |k, _v| fields.include?(k) }
          .merge(foreign_key),
      )

      if stack.include?(current_record)
        return [current_record]
      end

      [current_record] + associations.flat_map { |name, config|
        mapper = mappers.fetch(config.fetch(:mapping_name))
        associated_objects = serialized_record.fetch(name)

        case config.fetch(:type)
        when :one_to_many
          dump_one_to_many(mapper, associated_objects, config, stack + [current_record])
        when :many_to_one
          dump_many_to_one(mapper, associated_objects, config, stack + [current_record])
        when :many_to_many
          dump_many_to_many(mapper, associated_objects, config, stack + [current_record])
        else
          raise "Association type not supported"
        end
      }
    end

    private

    def upsert(namespace, record)
      # TODO the record must also carry its primary key field name
      existing = datastore[record.namespace].where(record.identity)

      if existing.empty?
        datastore[record.namespace].insert(record.to_h)
      else
        existing.update(record.to_h)
      end
    end

    # TODO: remove use of stack.last, doesn't communicate meaning very well
    def dump_one_to_many(mapper, associated, config, stack)
      foreign_key = {
        config.fetch(:foreign_key) => stack.last.fetch(config.fetch(:key)),
      }

      (associated || []).flat_map { |associated_record|
        mapper.dump(associated_record, foreign_key, stack)
      }
    end

    def dump_many_to_one(mapper, associated, config, stack)
      associated_record = mapper.dump(
        associated,
        {},
        stack,
      ).first

      foreign_key = {
        config.fetch(:foreign_key) => associated_record.fetch(config.fetch(:key)),
      }

      [
        associated_record,
        stack.last.merge(foreign_key),
      ]
    end

    def dump_many_to_many(mapper, associated, config, stack)
      (associated || []).flat_map { |associated_record|
        this_record = mapper.dump(associated_record, {}, stack).first

        [
          this_record,
          NamespacedRecord.new(
            config.fetch(:through_namespace),
            {
              config.fetch(:foreign_key) => stack.last.fetch(config.fetch(:key)),
              config.fetch(:association_foreign_key) => this_record.fetch(config.fetch(:association_key)),
            },
          ),
        ]
      }.flatten(1)
    end

    def record_identity(record)
      Hash[
        primary_key.map { |field|
          [field, record.fetch(field)]
        }
      ]
    end
  end
end
