require "sequel_mapper/mapper_facade"
require "sequel_mapper/relation_mapping"
require "sequel_mapper/queryable_lazy_dataset_loader"
require "sequel_mapper/lazy_object_proxy"
require "sequel_mapper/dataset"
require "support/object_graph_setup"

RSpec.shared_context "mapper setup" do
  include_context "object graph setup"

  let(:mappers) {
    {
      users: user_mapper,
    }
  }

  let(:user_mapper) {
    SequelMapper.mapper(
      config: mappings,
      name: :users,
      datastore: datastore,
    )
  }

  let(:mappings) {
    Hash[
      configs.map { |name, config|
        [
          name,
          SequelMapper::RelationMapping.new(
            name: name,
            namespace: config.fetch(:namespace),
            fields: config.fetch(:fields),
            primary_key: config.fetch(:primary_key),
            serializer: serializer.call(config.fetch(:fields) + config.fetch(:associations).keys),
            associations: config.fetch(:associations),
            factory: factories.fetch(name),
          )
        ]
      }
    ]
  }

  let(:has_many_proxy_factory) {
    ->(query:, loader:) {
      SequelMapper::QueryableLazyDatasetLoader.new(
        query.call(datastore),
        loader,
        :this_should_be_the_mapper,
      )
    }
  }

  let(:many_to_one_proxy_factory) {
    ->(query:, loader:, preloaded_data:) {
      SequelMapper::LazyObjectProxy.new(
        ->{ loader.call(query.call(datastore)) },
        preloaded_data,
      )
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
            through_namespace: :categories_to_posts,
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
            through_namespace: :categories_to_posts,
            proxy_factory: has_many_proxy_factory,
          },
        },
      },
    }
  }
end
