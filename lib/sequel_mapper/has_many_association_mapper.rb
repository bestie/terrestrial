require "sequel_mapper/abstract_association_mapper"
require "sequel_mapper/has_many_association_mapper_methods"

module SequelMapper
  class HasManyAssociationMapper < AbstractAssociationMapper
    include HasManyAssociationMapperMethods

    def initialize(key:, foreign_key:, order_by: {}, **args)
      # suffix with _field
      @key = key
      @foreign_key = foreign_key
      @order_by = order_by
      super(**args)
    end

    attr_reader :key, :foreign_key, :order_by
    private     :key, :foreign_key, :order_by

    def load_for_row(row)
      proxy_with_dataset(data_enum(row))
    end

    # TODO RENAME it is not clear from these method names what the difference is

    # #eager_load_association is the request to eager load an associated association
    def eager_load_association(dataset, association_name)
      rows = dataset.to_a

      association_by_name(association_name).eager_load(rows)

      proxy_with_dataset(rows)
    end

    # #eager_load takes the parent dataset and executes the loading
    def eager_load(rows)
      ids = rows.map { |row| row.fetch(key) }
      eager_dataset = apply_order(relation.where(foreign_key => ids)).to_a

      ids.each do |id|
        @eager_loads[id] = eager_dataset
      end
    end

    def save(_source_object, collection)
      unless_already_persisted(collection) do |collection_proxy|
        persist_nodes(collection)
        remove_deleted_nodes(collection_proxy)
      end
    end

    private

    def data_enum(row)
      if eagerly_loaded?(row)
        filter_preloaded_collection(row)
      else
        apply_order(query(row))
      end
    end

    # TODO: Add this ordering feature to HasManyThrough
    def apply_order(query)
      reverse_or_noop = order_by.fetch(:direction, :asc) == :desc ?
        :reverse : :from_self

      query
        .order(*order_by.fetch(:fields, []))
        .public_send(reverse_or_noop)
    end

    def query(row)
      relation.where(foreign_key => row.fetch(key))
    end

    def filter_preloaded_collection(row)
      id = row.fetch(key)

      @eager_loads
        .fetch(id)
        .select { |association_row|
          association_row.fetch(foreign_key) == id
        }
    end

    def proxy_with_dataset(dataset)
      proxy_factory.call(
        dataset,
        row_loader_func,
        # TODO: interface segregation, only #eager_load_association is used
        self,
      )
    end

    def persist_nodes(collection)
      nodes_to_persist(collection).each do |object|
        upsert_if_dirty(mapping.dump(object))
      end
    end

    def remove_deleted_nodes(collection)
      removed_nodes(collection).each do |node|
        delete_node(node)
      end
    end

    def delete_node(node)
      relation.where(id: node.id).delete
    end
  end
end
