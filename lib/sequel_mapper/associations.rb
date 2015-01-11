module SequelMapper
  module Associations
    class Association
      include MapperMethods

      def initialize(datastore:, proxy_factory:, dirty_map:, mappings:, mapping_name:)
        @datastore = datastore
        @proxy_factory = proxy_factory
        @dirty_map = dirty_map
        @mappings = mappings
        @mapping_name = mapping_name
        @eager_loads = {}
      end

      attr_reader :datastore, :dirty_map, :proxy_factory
      private :datastore, :dirty_map, :proxy_factory

      def load_for_row(_row)
        raise NotImplementedError
      end

      def save(_source_object, _collection)
        raise NotImplementedError
      end

      def eager_load_association(_dataset, _association_name)
        raise NotImplementedError
      end

      def foreign_key_field(_label, _object)
        {}
      end

      def eager_load(_foreign_key_field, _values)
        raise NotImplementedError
      end

      private

      def mapping
        @mapping ||= @mappings.fetch(@mapping_name) { |name|
          raise "Mapping #{name} not found"
        }
      end

      def loaded?(collection)
        if collection.respond_to?(:loaded?)
          collection.loaded?
        else
          true
        end
      end

      def eagerly_loaded?(row)
        !!@eager_loads.fetch(row.fetch(key), false)
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

      def row_loader_func
        ->(row) {
          dirty_map.store(row.fetch(:id), row)
          mapping.load(row)
        }
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

      def load_for_row(row)
        proxy_factory.call(eagerly_loaded(row) || dataset(row))
      end

      def save(_source_object, object)
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

      def eager_load(_foreign_key_field, rows)
        foreign_key_values = rows.map { |row| row.fetch(foreign_key) }
        ids = rows.map { |row| row.fetch(:id) }

        eager_object = relation.where(:id => foreign_key_values).first

        ids.each do |id|
          @eager_loads[id] = eager_object
        end
      end

      private

      def dataset(row)
        ->() {
          relation
            .where(:id => row.fetch(foreign_key))
            .map(&row_loader_func)
            .first
        }
      end

      def eagerly_loaded(row)
        associated_row = @eager_loads.fetch(row.fetch(:id), nil)

        if associated_row
          ->() { row_loader_func.call(associated_row) }
        else
          nil
        end
      end
    end

    class HasMany < Association
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

      def association_by_name(name)
        # TODO: obviously this
        mapping
          .instance_variable_get(:@mapping)
          .instance_variable_get(:@associations)
          .fetch(name)
      end

      def eager_load_association(dataset, association_name)
        rows = dataset.to_a

        association_by_name(association_name).eager_load(foreign_key, rows)

        proxy_with_dataset(rows)
      end

      def save(_source_object, collection)
        unless_already_persisted(collection) do |collection_proxy|
          persist_nodes(collection)
          remove_deleted_nodes(collection_proxy)
        end
      end

      def eager_load(foreign_key_field, rows)
        ids = rows.map { |row| row.fetch(key) }
        eager_dataset = apply_order(relation.where(foreign_key => ids)).to_a

        ids.each do |id|
          @eager_loads[id] = eager_dataset
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
        datastore[relation_name]
          .where(foreign_key => row.fetch(key))
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

    class HasManyThrough < Association
      def initialize(through_relation_name:, foreign_key:, association_foreign_key:, **args)
        @through_relation_name = through_relation_name
        @foreign_key = foreign_key
        @association_foreign_key = association_foreign_key
        super(**args)
      end

      attr_reader :through_relation_name, :foreign_key, :association_foreign_key
      private     :through_relation_name, :foreign_key, :association_foreign_key

      def load_for_row(row)
        proxy_factory.call(
          datastore[relation_name].where(:id => ids(row)),
          row_loader_func,
        )
      end

      def save(source_object, collection)
        unless_already_persisted(collection) do |collection|
          persist_nodes(collection)
          associate_new_nodes(source_object, collection)
          dissociate_removed_nodes(source_object, collection)
        end
      end

      private

      def ids(row)
        datastore[through_relation_name]
          .select(association_foreign_key)
          .where(foreign_key => row.fetch(:id))
      end

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
