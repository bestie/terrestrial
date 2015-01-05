require "sequel_mapper/belongs_to_association_proxy"
require "sequel_mapper/association_proxy"

module SequelMapper
  module Associations
    class Association
      include MapperMethods

      def initialize(datastore:, mappings:, mapping:, dirty_map:)
        @datastore = datastore
        @mappings = mappings
        @mapping_name = mapping
        @dirty_map = dirty_map
      end

      attr_reader :datastore, :mapping, :dirty_map

      def load(_row)
        raise NotImplementedError
      end

      def dump(_source_object, _collection)
        raise NotImplementedError
      end

      def foreign_key_field(_label, _object)
        {}
      end

      private

      def mapping
        @mappings.fetch(@mapping_name)
      end

      def loaded?(collection)
        if collection.respond_to?(:loaded?)
          collection.loaded?
        else
          true
        end
      end

      def added_nodes(collection)
        collection.respond_to?(:added_nodes) ? collection.added_nodes : collection
      end

      def removed_nodes(collection)
        collection.respond_to?(:removed_nodes) ? collection.removed_nodes : []
      end

      def nodes_to_persist(collection)
        if loaded?(collection)
          collection
        else
          added_nodes(collection)
        end
      end
    end

    # Association loads the correct associated row from the database,
    # constructs the correct proxy delegating to the RowMapper
    class BelongsTo < Association
      def initialize(foreign_key:, **args)
        @foreign_key = foreign_key
        super(**args)
      end

      attr_reader :foreign_key
      private     :foreign_key

      def load(row)
        BelongsToAssociationProxy.new(
          datastore[relation_name]
            .where(:id => row.fetch(foreign_key))
            .lazy
            .map { |row| dirty_map.store(row.fetch(:id), row) }
            .map { |row| mapping.load(row) }
            .public_method(:first)
        )
      end

      def dump(_source_object, object)
        unless_already_persisted(object) do |object|
          if loaded?(object)
            upsert_if_dirty(mapping.dump(object))
          end
        end
      end

      def foreign_key_field(name, object)
        {
          foreign_key => object.public_send(name).public_send(:id)
        }
      end
    end

    class HasMany < Association
      def initialize(key:, foreign_key:, order_by: {}, **args)
        @key = key
        @foreign_key = foreign_key
        @order_by = order_by
        super(**args)
      end

      attr_reader :key, :foreign_key, :order_by
      private     :key, :foreign_key, :order_by

      def load(row)

        AssociationProxy.new(
          data_enum(row)
            .lazy
            .map { |row| dirty_map.store(row.fetch(:id), row) }
            .map { |row| mapping.load(row) }
        )
      end

      def dump(_source_object, collection)
        unless_already_persisted(collection) do |collection_proxy|
          persist_nodes(collection)
          remove_deleted_nodes(collection_proxy)
        end
      end

      private

      def data_enum(row)
        apply_order(query(row))
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
        datastore[relation_name]
          .where(foreign_key => row.fetch(key))
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

    class HasManyThrough < Association
      def initialize(through_relation_name:, foreign_key:, association_foreign_key:, **args)
        @through_relation_name = through_relation_name
        @foreign_key = foreign_key
        @association_foreign_key = association_foreign_key
        super(**args)
      end

      attr_reader :through_relation_name, :foreign_key, :association_foreign_key
      private     :through_relation_name, :foreign_key, :association_foreign_key

      def load(row)
        ids = datastore[through_relation_name]
                .select(association_foreign_key)
                .where(foreign_key => row.fetch(:id))

        AssociationProxy.new(
          datastore[relation_name]
            .where(:id => ids)
            .lazy
            .map { |row| dirty_map.store(row.fetch(:id), row) }
            .map { |row| mapping.load(row) }
        )
      end

      def dump(source_object, collection)
        unless_already_persisted(collection) do |collection|
          persist_nodes(collection)
          associate_new_nodes(source_object, collection)
          dissociate_removed_nodes(source_object, collection)
        end
      end

      private

      def persist_nodes(collection)
        nodes_to_persist(collection).each do |object|
          upsert_if_dirty(mapping.dump(object))
        end
      end

      def associate_new_nodes(source_object, collection)
        added_nodes(collection).each do |node|
          through_relation.insert(
            foreign_key => source_object.public_send(:id),
            association_foreign_key => node.public_send(:id),
          )
        end
      end

      def dissociate_removed_nodes(source_object, collection)
        ids = removed_nodes(collection).map(&:id)

        through_relation
          .where(
            foreign_key => source_object.public_send(:id),
            association_foreign_key => ids,
          )
          .delete
      end

      def through_relation
        datastore[through_relation_name]
      end
    end
  end
end
