require "sequel_mapper/namespaced_record"

module SequelMapper
  class MapperFacade
    def initialize(mappings:, mapping_name:, datastore:, dataset:)
      @mappings = mappings
      @mapping_name = mapping_name
      @datastore = datastore
      @dataset = dataset
    end

    attr_reader :mappings, :mapping_name, :datastore, :dataset
    private     :mappings, :mapping_name, :datastore, :dataset

    def save(graph)
      record_dump = graph_serializer.call(mapping_name, graph)

      record_dump.each do |record|
        upsert(record)
      end

      self
    end

    private

    def graph_serializer
      GraphSerializer.new(
        mappings: mappings,
      )
    end

    def upsert(record)
      existing = datastore[record.namespace].where(record.identity)

      if existing.empty?
        datastore[record.namespace].insert(record.to_h)
      else
        existing.update(record.to_h)
      end
    end
  end

  class GraphSerializer
    def initialize(mappings:)
      @mappings = mappings
    end

    attr_reader :mappings

    def call(mapping_name, object, foreign_key = {}, stack = [])
      mapping = mappings.fetch(mapping_name)
      serializer = mapping.serializer
      namespace = mapping.namespace
      primary_key = mapping.primary_key
      fields = mapping.fields
      associations = mapping.associations

      serialized_record = serializer.call(object)

      current_record = NamespacedRecord.new(
        namespace,
        record_identity(primary_key, serialized_record),
        serialized_record
          .select { |k, _v| fields.include?(k) }
          .merge(foreign_key),
      )

      if stack.include?(current_record)
        return [current_record]
      end

      [current_record] + associations.flat_map { |name, config|
        mapping = mappings.fetch(config.fetch(:mapping_name))
        associated_objects = serialized_record.fetch(name)

        case config.fetch(:type)
        when :one_to_many
          dump_one_to_many(mapping, associated_objects, config, stack + [current_record])
        when :many_to_one
          dump_many_to_one(mapping, associated_objects, config, stack + [current_record])
        when :many_to_many
          dump_many_to_many(mapping, associated_objects, config, stack + [current_record])
        else
          raise "Association type not supported"
        end
      }
    end

    private

    # TODO: remove use of stack.last, doesn't communicate meaning very well
    def dump_one_to_many(mapping, associated, config, stack)
      foreign_key = {
        config.fetch(:foreign_key) => stack.last.fetch(config.fetch(:key)),
      }

      (associated || []).flat_map { |associated_record|
        call(mapping.name, associated_record, foreign_key, stack)
      }
    end

    def dump_many_to_one(mapping, associated, config, stack)
      associated_record = call(
        mapping.name,
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

    def dump_many_to_many(mapping, associated, config, stack)
      (associated || []).flat_map { |associated_record|
        this_record = call(mapping.name, associated_record, {}, stack).first

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

    def record_identity(primary_key, record)
      Hash[
        primary_key.map { |field|
          [field, record.fetch(field)]
        }
      ]
    end
  end
end
