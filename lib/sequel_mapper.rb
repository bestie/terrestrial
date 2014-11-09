module SequelMapper
  class Graph
    def initialize(datastore:, top_level_namespace:, relation_mappings:)
      @top_level_namespace = top_level_namespace
      @datastore = datastore
      @relation_mappings = relation_mappings
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
      datastore[top_level_namespace]
        .where(id: graph_root.id)
        .update(
          dump(
            relation_mappings.fetch(top_level_namespace),
            graph_root,
          )
        )
    end

    private

    def dump(relation, row)
      row.to_h.select { |field_name, _v|
        relation.fetch(:columns).include?(field_name)
      }
    end

    def associations_types
      %i(
        has_many
        has_many_through
        belongs_to
      )
    end

    def load(relation, row)
      has_many_associations = Hash[
        relation.fetch(:has_many, []).map { |assoc_name, assoc|
         [
            assoc_name,
            datastore[assoc.fetch(:relation_name)]
              .where(assoc.fetch(:foreign_key) => row.fetch(:id))
              .lazy
              .map { |row|
                load(relation_mappings.fetch(assoc.fetch(:relation_name)), row)
              }
          ]
        }
      ]

      belongs_to_associations = Hash[
        relation.fetch(:belongs_to, []).map { |assoc_name, assoc|
         [
            assoc_name,
            datastore[assoc.fetch(:relation_name)]
              .where(:id => row.fetch(assoc.fetch(:foreign_key)))
              .map { |row|
                load(relation_mappings.fetch(assoc.fetch(:relation_name)), row)
              }
              .fetch(0)
          ]
        }
      ]

      has_many_through_assocations = Hash[
        relation.fetch(:has_many_through, []).map { |assoc_name, assoc|
         [
            assoc_name,
            datastore[assoc.fetch(:relation_name)]
              .where(
                :id => datastore[assoc.fetch(:through_relation_name)]
                        .where(assoc.fetch(:foreign_key) => row.fetch(:id))
                        .map { |row| row.fetch(assoc.fetch(:association_foreign_key)) }
              )
              .lazy
              .map { |row|
                load(relation_mappings.fetch(assoc.fetch(:relation_name)), row)
              }
          ]
        }
      ]

      relation.fetch(:factory).call(
        row
          .merge(has_many_associations)
          .merge(has_many_through_assocations)
          .merge(belongs_to_associations)
      )
    end
  end

  class StructFactory
    def initialize(struct_class)
      @constructor = struct_class.method(:new)
      @members = struct_class.members
    end

    attr_reader :constructor, :members
    private     :constructor, :members

    def call(data)
      constructor.call(
        *members.map { |m| data.fetch(m, nil) }
      )
    end
  end
end
