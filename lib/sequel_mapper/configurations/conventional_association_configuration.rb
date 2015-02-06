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
        @mapping_name = mapping_name
        @mappings = mappings
        @dirty_map = dirty_map
        @datastore = datastore
      end

      attr_reader :mapping_name, :mappings, :dirty_map, :datastore
      private     :mapping_name, :mappings, :dirty_map, :datastore

      DEFAULT = :use_convention

      def has_many(association_name, key: DEFAULT, foreign_key: DEFAULT, table_name: DEFAULT, order_by: DEFAULT)
        defaults = {
          table_name: association_name,
          foreign_key: [INFLECTOR.singularize(mapping_name), "_id"].join.to_sym,
          key: :id,
          order_by: [[]],
        }

        specified = {
          table_name: table_name,
          foreign_key: foreign_key,
          key: key,
          order_by: order_by,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults.merge(specified)
        config = config.merge(
            name: association_name,
            relation: datastore[config.fetch(:table_name)],
          )
        config.delete(:table_name)

        mappings.fetch(association_name).mark_foreign_key(config.fetch(:foreign_key))
        mappings[mapping_name].add_association(association_name, has_many_mapper(**config))
      end

      def belongs_to(association_name, key: DEFAULT, foreign_key: DEFAULT, table_name: DEFAULT)
        defaults = {
          key: :id,
          foreign_key: [association_name, "_id"].join.to_sym,
          table_name: INFLECTOR.pluralize(association_name).to_sym,
        }

        specified = {
          table_name: table_name,
          foreign_key: foreign_key,
          key: key,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults
          .merge(specified)

        config.store(:name, config.fetch(:table_name))
        config.store(:relation, datastore[config.fetch(:table_name)])
        config.delete(:table_name)

        mappings.fetch(mapping_name).mark_foreign_key(config.fetch(:foreign_key))
        mappings[mapping_name].add_association(association_name, belongs_to_mapper(**config))
      end

      def has_many_through(association_name, key: DEFAULT, foreign_key: DEFAULT, table_name: DEFAULT, join_table_name: DEFAULT, association_foreign_key: DEFAULT)
        defaults = {
          table_name: association_name,
          foreign_key: [INFLECTOR.singularize(mapping_name), "_id"].join.to_sym,
          association_foreign_key: [INFLECTOR.singularize(association_name), "_id"].join.to_sym,
          join_table_name: [association_name, mapping_name].sort.join("_to_"),
          key: :id,
        }

        specified = {
          table_name: table_name,
          foreign_key: foreign_key,
          association_foreign_key: association_foreign_key,
          join_table_name: join_table_name,
          key: key,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults.merge(specified)

        config = config
          .merge(
            name: association_name,
            relation: datastore[config.fetch(:table_name).to_sym],
            through_relation: datastore[config.fetch(:join_table_name).to_sym],
          )

        config.delete(:table_name)
        config.delete(:join_table_name)

        mappings[mapping_name].add_association(association_name, has_many_through_mapper(**config))
      end

      private

      def has_many_mapper(name:, relation:, key:, foreign_key:, order_by:)
        HasManyAssociationMapper.new(
          foreign_key: foreign_key,
          key: key,
          relation: relation,
          mapping_name: name,
          dirty_map: dirty_map,
          proxy_factory: collection_proxy_factory,
          mappings: mappings,
          order_by: order_by,
        )
      end

      def belongs_to_mapper(name:, relation:, key:, foreign_key:)
        BelongsToAssociationMapper.new(
          foreign_key: foreign_key,
          key: key,
          relation: relation,
          mapping_name: name,
          dirty_map: dirty_map,
          proxy_factory: single_object_proxy_factory,
          mappings: mappings,
        )
      end

      def has_many_through_mapper(name:, relation:, through_relation:, key:, foreign_key:, association_foreign_key:)
        HasManyThroughAssociationMapper.new(
          foreign_key: foreign_key,
          association_foreign_key: association_foreign_key,
          key: key,
          relation: relation,
          through_relation: through_relation,
          mapping_name: name,
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
