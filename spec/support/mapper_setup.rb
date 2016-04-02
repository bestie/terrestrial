require "sequel_mapper"
require "sequel_mapper/mapper_facade"
require "sequel_mapper/relation_mapping"
require "sequel_mapper/lazy_collection"
require "sequel_mapper/collection_mutability_proxy"
require "sequel_mapper/lazy_object_proxy"
require "sequel_mapper/dataset"
require "sequel_mapper/query_order"
require "sequel_mapper/one_to_many_association"
require "sequel_mapper/many_to_one_association"
require "sequel_mapper/many_to_many_association"
require "sequel_mapper/subset_queries_proxy"
require "support/object_graph_setup"

RSpec.shared_context "mapper setup" do
  include_context "object graph setup"

  let(:mappers) {
    Terrestrial.mappers(mappings: mappings, datastore: datastore)
  }

  let(:user_mapper) { mappers[:users] }

  let(:mappings) {
    Hash[
      configs.map { |name, config|
        fields = config.fetch(:fields) + config.fetch(:associations).keys

        associations = config.fetch(:associations).map { |assoc_name, assoc_config|
          [
            assoc_name,
            case assoc_config.fetch(:type)
            when :one_to_many
              Terrestrial::OneToManyAssociation.new(
                **assoc_defaults.merge(
                  assoc_config.dup.tap { |h| h.delete(:type) }
                )
              )
            when :many_to_one
              Terrestrial::ManyToOneAssociation.new(
                assoc_config.dup.tap { |h| h.delete(:type) }
              )
            when :many_to_many
              Terrestrial::ManyToManyAssociation.new(
                **assoc_defaults
                  .merge(
                    join_mapping_name: assoc_config.fetch(:join_mapping_name),
                  )
                  .merge(
                    assoc_config.dup.tap { |h|
                      h.delete(:type)
                      h.delete(:join_namespace)
                    }
                  )
              )
            else
              raise "Association type not supported"
            end
          ]
        }

        [
          name,
          Terrestrial::RelationMapping.new(
            name: name,
            namespace: config.fetch(:namespace),
            fields: config.fetch(:fields),
            primary_key: config.fetch(:primary_key),
            serializer: serializers.fetch(config.fetch(:serializer)).call(fields),
            associations: Hash[associations],
            factory: factories.fetch(name),
            subsets: Terrestrial::SubsetQueriesProxy.new(config.fetch(:subsets, {}))
          )
        ]
      }
    ]
  }

  def assoc_defaults
    {
      order: Terrestrial::QueryOrder.new(fields: [], direction: "ASC")
    }
  end

  let(:has_many_proxy_factory) {
    ->(query:, loader:, mapping_name:) {
      Terrestrial::CollectionMutabilityProxy.new(
        Terrestrial::LazyCollection.new(
          query,
          loader,
          mappings.fetch(mapping_name).subsets,
        )
      )
    }
  }

  let(:many_to_one_proxy_factory) {
    ->(query:, loader:, preloaded_data:) {
      Terrestrial::LazyObjectProxy.new(
        ->{ loader.call(query.first) },
        preloaded_data,
      )
    }
  }

  let(:serializers) {
    {
      default: default_serializer,
      null: null_serializer,
    }
  }

  let(:configs) {
    {
      users: {
        namespace: :users,
        primary_key: [:id],
        fields: [
          :id,
          :first_name,
          :last_name,
          :email,
        ],
        factory: :user,
        serializer: :default,
        associations: {
          posts: {
            type: :one_to_many,
            mapping_name: :posts,
            foreign_key: :author_id,
            key: :id,
            proxy_factory: has_many_proxy_factory,
          }
        },
      },

      posts: {
        namespace: :posts,
        primary_key: [:id],
        fields: [
          :id,
          :subject,
          :body,
          :created_at,
        ],
        factory: :post,
        serializer: :default,
        associations: {
          comments: {
            type: :one_to_many,
            mapping_name: :comments,
            foreign_key: :post_id,
            key: :id,
            proxy_factory: has_many_proxy_factory,
          },
          categories: {
            type: :many_to_many,
            mapping_name: :categories,
            key: :id,
            foreign_key: :post_id,
            association_foreign_key: :category_id,
            association_key: :id,
            join_mapping_name: :categories_to_posts,
            proxy_factory: has_many_proxy_factory,
          },
        },
      },

      comments: {
        namespace: :comments,
        primary_key: [:id],
        fields: [
          :id,
          :body,
        ],
        factory: :comment,
        serializer: :default,
        associations: {
          commenter: {
            type: :many_to_one,
            mapping_name: :users,
            key: :id,
            foreign_key: :commenter_id,
            proxy_factory: many_to_one_proxy_factory,
          },
        },
      },

      categories: {
        namespace: :categories,
        primary_key: [:id],
        fields: [
          :id,
          :name,
        ],
        factory: :comment,
        serializer: :default,
        associations: {
          posts: {
            type: :many_to_many,
            mapping_name: :posts,
            key: :id,
            foreign_key: :category_id,
            association_foreign_key: :post_id,
            association_key: :id,
            join_mapping_name: :categories_to_posts,
            proxy_factory: has_many_proxy_factory,
          },
        },
      },

      categories_to_posts: {
        namespace: :categories_to_posts,
        primary_key: [:category_id, :post_id],
        fields: [],
        serializer: :null,
        associations: {},
      }
    }
  }
end
