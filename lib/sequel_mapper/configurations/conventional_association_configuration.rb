module SequelMapper
  module Configurations
    require "sequel_mapper/belongs_to_association_mapper"
    require "sequel_mapper/has_many_association_mapper"
    require "sequel_mapper/has_many_through_association_mapper"
    require "sequel_mapper/collection_mutability_proxy"
    require "sequel_mapper/queryable_lazy_dataset_loader"
    require "sequel_mapper/lazy_object_proxy"

    class ConventionalAssociationConfiguration
      def initialize(mapping_name, mappings, dirty_map, datastore)
        @local_mapping_name = mapping_name
        @mappings = mappings
        @local_mapping = mappings.fetch(local_mapping_name)
        @dirty_map = dirty_map
        @datastore = datastore
      end

      attr_reader :local_mapping_name, :local_mapping, :mappings, :dirty_map, :datastore
      private     :local_mapping_name, :local_mapping, :mappings, :dirty_map, :datastore

      DEFAULT = :use_convention

      def has_many(association_name, key: DEFAULT, foreign_key: DEFAULT, mapping_name: DEFAULT, order_by: DEFAULT)
        defaults = {
          mapping_name: association_name,
          foreign_key: [INFLECTOR.singularize(local_mapping_name), "_id"].join.to_sym,
          key: :id,
          order_by: [[]],
        }

        specified = {
          mapping_name: mapping_name,
          foreign_key: foreign_key,
          key: key,
          order_by: order_by,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults.merge(specified)
        associated_mapping_name = config.fetch(:mapping_name)
        associated_mapping = mappings.fetch(associated_mapping_name)

        config = config.merge(
          relation: datastore[associated_mapping.relation_name],
        )

        associated_mapping.mark_foreign_key(config.fetch(:foreign_key))

        local_mapping.add_association(
          association_name,
          has_many_mapper(**config)
        )
      end

      def belongs_to(association_name, key: DEFAULT, foreign_key: DEFAULT, mapping_name: DEFAULT)
        defaults = {
          key: :id,
          foreign_key: [association_name, "_id"].join.to_sym,
          mapping_name: INFLECTOR.pluralize(association_name).to_sym,
        }

        specified = {
          mapping_name: mapping_name,
          foreign_key: foreign_key,
          key: key,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults.merge(specified)

        associated_mapping_name = config.fetch(:mapping_name)
        associated_mapping = mappings.fetch(associated_mapping_name)


        config.store(:relation, datastore[associated_mapping.relation_name])

        local_mapping.mark_foreign_key(config.fetch(:foreign_key))

        local_mapping.add_association(
          association_name,
          belongs_to_mapper(**config)
        )
      end

      def has_many_through(association_name, key: DEFAULT, foreign_key: DEFAULT, mapping_name: DEFAULT, join_table_name: DEFAULT, association_foreign_key: DEFAULT)
        defaults = {
          mapping_name: association_name,
          foreign_key: [INFLECTOR.singularize(local_mapping_name), "_id"].join.to_sym,
          association_foreign_key: [INFLECTOR.singularize(association_name), "_id"].join.to_sym,
          key: :id,
        }

        specified = {
          mapping_name: mapping_name,
          foreign_key: foreign_key,
          association_foreign_key: association_foreign_key,
          key: key,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults.merge(specified)
        associated_mapping = mappings.fetch(config.fetch(:mapping_name))

        # TODO Would be nice to supply a join_mapping param in case the
        # 'through relation' represents an entity itself
        if join_table_name == DEFAULT
          join_table_name = [
            associated_mapping.relation_name,
            local_mapping.relation_name,
          ].sort.join("_to_")
        end

        config = config
          .merge(
            relation: datastore[associated_mapping.relation_name],
            through_relation: datastore[join_table_name.to_sym],
          )

        local_mapping.add_association(
          association_name,
          has_many_through_mapper(**config)
        )
      end

      private

      def has_many_mapper(mapping_name:, relation:, key:, foreign_key:, order_by:)
        HasManyAssociationMapper.new(
          foreign_key: foreign_key,
          key: key,
          relation: relation,
          mapping_name: mapping_name,
          dirty_map: dirty_map,
          proxy_factory: collection_proxy_factory,
          mappings: mappings,
          order_by: order_by,
        )
      end

      def belongs_to_mapper(mapping_name:, relation:, key:, foreign_key:)
        BelongsToAssociationMapper.new(
          foreign_key: foreign_key,
          key: key,
          relation: relation,
          mapping_name: mapping_name,
          dirty_map: dirty_map,
          proxy_factory: single_object_proxy_factory,
          mappings: mappings,
        )
      end

      def has_many_through_mapper(mapping_name:, relation:, through_relation:, key:, foreign_key:, association_foreign_key:)
        HasManyThroughAssociationMapper.new(
          foreign_key: foreign_key,
          association_foreign_key: association_foreign_key,
          key: key,
          relation: relation,
          through_relation: through_relation,
          mapping_name: mapping_name,
          dirty_map: dirty_map,
          proxy_factory: collection_proxy_factory,
          mappings: mappings,
        )
      end

      def single_object_proxy_factory
        LazyObjectProxy.method(:new)
      end

      def collection_proxy_factory
        ->(*args) {
          CollectionMutabilityProxy.new(
            QueryableLazyDatasetLoader.new(*args)
          )
        }
      end
    end
  end
end
