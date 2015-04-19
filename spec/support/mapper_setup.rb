require "sequel_mapper/mapper_facade"
require "sequel_mapper/relation_mapping"
require "sequel_mapper/dataset"
require "support/object_graph_setup"

RSpec.shared_context "mapper setup" do
  include_context "object graph setup"

  let(:mappers) {
    {
      users: SequelMapper::MapperFacade.new(
        mappings: mappings,
        mapping_name: :users,
        datastore: datastore,
        dataset: datastore[:users],
      )
    }
  }

  let(:mappings) {
    registry = {}

    configs.each { |name, config|
      registry[name] = SequelMapper::RelationMapping.new(
        name: name,
        namespace: config.fetch(:namespace),
        fields: config.fetch(:fields),
        primary_key: config.fetch(:primary_key),

        serializer: serializer.call(config.fetch(:fields) + config.fetch(:associations).keys),
        associations: config.fetch(:associations),
        # mappers: registry,
        # datastore: datastore,
        # dataset: SequelMapper::Dataset.new([]),
      )
    }

    registry
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
          },
          categories: {
            type: :many_to_many,
            mapping_name: :categories,
            key: :id,
            foreign_key: :post_id,
            association_foreign_key: :category_id,
            association_key: :id,
            through_namespace: :categories_to_posts,
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
          },
        },
      },
    }
  }
end
