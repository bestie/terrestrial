require "sequel_mapper/association_proxy"
require "sequel_mapper/belongs_to_association_proxy"
require "sequel_mapper/queryable_association_proxy"

module SequelMapper
  class Mapper
    def initialize(datastore:, top_level_namespace:, mappings:)
      @top_level_namespace = top_level_namespace
      @datastore = datastore
      @relation_mappings = mappings
    end

    attr_reader :top_level_namespace, :datastore, :relation_mappings
    private     :top_level_namespace, :datastore, :relation_mappings

    def where(criteria)
      datastore[top_level_namespace]
        .where(criteria)
        .map { |row|
          load(
            relation_mappings.fetch(top_level_namespace),
            row,
          )
        }
    end

    def save(graph_root)
      @persisted_objects = []
      dump(top_level_namespace, graph_root)
    end

    private

    def identity_map
      @identity_map ||= {}
    end

    def dirty_map
      @dirty_map ||= {}
    end

    def row_dirty?(row)
      loaded_row = dirty_map.fetch(row.fetch(:id), :not_found_therefore_dirty)

      row != loaded_row
    end

    def object_to_row(relation, object)
      object.to_h.select { |field_name, _v|
        relation.fetch(:columns).include?(field_name)
      }
    end

    def dump(relation_name, object)
      return if @persisted_objects.include?(object)
      @persisted_objects.push(object)

      relation = relation_mappings.fetch(relation_name)

      row = object_to_row(relation, object)

      # TODO: dirty tracking (for update efficiency) only works for objects
      #       that belong to another when the association is defined in both
      #       directions
      relation.fetch(:belongs_to, []).each do |assoc_name, assoc_config|
        row[assoc_config.fetch(:foreign_key)] = object.public_send(assoc_name).id
      end

      relation.fetch(:has_many, []).each do |assoc_name, assoc_config|
        collection = object.public_send(assoc_name)
        collection_loaded = collection.respond_to?(:loaded?) ?
          collection.loaded? : true

        if collection_loaded
          collection.each do |assoc_object|
            dump(assoc_config.fetch(:relation_name), assoc_object)
          end
        end

        if collection.respond_to?(:added_nodes)
          collection.added_nodes.each do |assoc_object|
            dump(assoc_config.fetch(:relation_name), assoc_object)
          end
        end

        next unless collection.respond_to?(:removed_nodes)
        collection.removed_nodes.each do |removed_node|
          datastore[assoc_config.fetch(:relation_name)]
            .where(id: removed_node.id)
            .delete
        end
      end

      relation.fetch(:has_many_through, []).each do |assoc_name, assoc_config|
        collection = object.public_send(assoc_name)
        collection_loaded = collection.respond_to?(:loaded?) ?
          collection.loaded? : true

        if collection_loaded
          collection.each do |assoc_object|
            dump(assoc_config.fetch(:relation_name), assoc_object)
          end
        end

        next unless collection.respond_to?(:added_nodes)
        collection.added_nodes.each do |added_node|
          datastore[assoc_config.fetch(:through_relation_name)]
            .insert(
              assoc_config.fetch(:foreign_key) => object.id,
              assoc_config.fetch(:association_foreign_key) => added_node.id,
            )
        end

        collection.removed_nodes.each do |removed_node|
          datastore[assoc_config.fetch(:through_relation_name)]
            .where(assoc_config.fetch(:association_foreign_key) => removed_node.id)
            .delete
        end
      end

      if row_dirty?(row)
        existing = datastore[relation_name]
          .where(id: object.id)

        if existing.empty?
          datastore[relation_name].insert(row)
        else
          existing.update(row)
        end
      end
    end

    def load(relation, row)
      previously_loaded_object = identity_map.fetch(row.fetch(:id), false)
      return previously_loaded_object if previously_loaded_object

      # puts "****************LOADING #{row.fetch(:id)}"

      has_many_associations = Hash[
        relation.fetch(:has_many, []).map { |assoc_name, assoc|
          data_enum = datastore[assoc.fetch(:relation_name)]
            .where(assoc.fetch(:foreign_key) => row.fetch(:id))

          if assoc.fetch(:order_by, false)
            data_enum = data_enum.order(assoc.fetch(:order_by, {}).fetch(:columns, []))

            if assoc.fetch(:order_by).fetch(:direction, :asc) == :desc
              data_enum = data_enum.reverse
            end
          end

         [
            assoc_name,
            AssociationProxy.new(
              QueryableAssociationProxy.new(
                data_enum,
                ->(row) {
                  load(relation_mappings.fetch(assoc.fetch(:relation_name)), row)
                },
              )
            )
          ]
        }
      ]

      belongs_to_associations = Hash[
        relation.fetch(:belongs_to, []).map { |assoc_name, assoc|
         [
            assoc_name,
            BelongsToAssociationProxy.new(
              datastore[assoc.fetch(:relation_name)]
                .where(:id => row.fetch(assoc.fetch(:foreign_key)))
                .lazy
                .map { |row|
                  load(relation_mappings.fetch(assoc.fetch(:relation_name)), row)
                }
                .public_method(:first)
            )
          ]
        }
      ]

      has_many_through_assocations = Hash[
        relation.fetch(:has_many_through, []).map { |assoc_name, assoc|
         [
            assoc_name,
            AssociationProxy.new(
              QueryableAssociationProxy.new(
                datastore[assoc.fetch(:relation_name)]
                  .join(assoc.fetch(:through_relation_name), assoc.fetch(:association_foreign_key) => :id)
                  .where(assoc.fetch(:foreign_key) => row.fetch(:id)),
                ->(row) {
                  load(relation_mappings.fetch(assoc.fetch(:relation_name)), row)
                },
              )
            )
          ]
        }
      ]

      relation.fetch(:factory).call(
        row
          .merge(has_many_associations)
          .merge(has_many_through_assocations)
          .merge(belongs_to_associations)
      ).tap { |object|
        identity_map.store(row.fetch(:id), object)
        dirty_map.store(row.fetch(:id), row)
      }
    end
  end
end
