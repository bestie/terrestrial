module SequelMapper
  class Loader
    def initialize(datastore, relation_mappings, identity_map, dirty_map)
      @datastore = datastore
      @relation_mappings = relation_mappings
      @identity_map = identity_map
      @dirty_map = dirty_map
    end

    def call(relation, row)
      ensure_loaded_once(row) {
        relation.fetch(:factory).call(
          row.merge(associations(relation_mappings, relation, row))
        )
      }
    end

    private

    attr_reader(
      :datastore,
      :relation_mappings,
      :identity_map,
      :dirty_map,
    )

    def ensure_loaded_once(row, &block)
      identity_map.fetch(row.fetch(:id), false) or block.call.tap { |object|
          register(object, row)
        }
    end

    def associations(relation_mappings, relation, row)
      {}.merge(has_many_associations(relation_mappings, relation, row))
        .merge(has_many_through_associations(relation_mappings, relation, row))
        .merge(belongs_to_associations(relation_mappings, relation, row))
    end

    def register(object, row)
      identity_map.store(row.fetch(:id), object)
      dirty_map.store(row.fetch(:id), row)
    end

    def belongs_to_associations(relation_mappings, relation, row)
      Hash[
        relation.fetch(:belongs_to, []).map { |assoc_name, assoc|
         [
            assoc_name,
            BelongsToAssociationProxy.new(
              datastore[assoc.fetch(:relation_name)]
                .where(:id => row.fetch(assoc.fetch(:foreign_key)))
                .lazy
                .map { |row|
                  call(relation_mappings.fetch(assoc.fetch(:relation_name)), row)
                }
                .public_method(:first)
            )
          ]
        }
      ]
    end

    def has_many_associations(relation_mappings, relation, row)
      Hash[
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
                  call(relation_mappings.fetch(assoc.fetch(:relation_name)), row)
                },
              )
            )
          ]
        }
      ]
    end

    def has_many_through_associations(relation_mappings, relation, row)
      Hash[
        relation.fetch(:has_many_through, []).map { |assoc_name, assoc|

          # TODO: qualify column names with table name to avoid potential
          #       ambiguity
          assoc_value_columns = relation_mappings
            .fetch(assoc.fetch(:relation_name))
            .fetch(:columns)

         [
            assoc_name,
            AssociationProxy.new(
              QueryableAssociationProxy.new(
                datastore[assoc.fetch(:relation_name)]
                  .select(*assoc_value_columns)
                  .join(assoc.fetch(:through_relation_name), assoc.fetch(:association_foreign_key) => :id)
                  .where(assoc.fetch(:foreign_key) => row.fetch(:id)),
                ->(row) {
                  call(relation_mappings.fetch(assoc.fetch(:relation_name)), row)
                },
              )
            )
          ]
        }
      ]
    end
  end
end
