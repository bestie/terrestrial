require "sequel_mapper/mapper"
require "sequel_mapper/serializer"
require "sequel_mapper/dataset"
require "sequel_mapper/struct_factory"

RSpec.shared_context "mapper setup" do
  User = Struct.new(:id, :first_name, :last_name, :email, :posts, :comments)
  Post = Struct.new(:id, :author, :subject, :body, :comments, :categories)
  Comment = Struct.new(:id, :post, :commenter, :body)

  let(:factories) {
    {
      users: SequelMapper::StructFactory.new(User),
      posts: SequelMapper::StructFactory.new(Post),
      comments: SequelMapper::StructFactory.new(Comment),
    }
  }

  let(:serializer) {
    ->(fields) {
      ->(object) {
        SequelMapper::Serializer.new(fields, object).to_h
      }
    }
  }

  let(:mappers) {
    registry = {}

    configs.each { |name, config|
      registry[name] = SequelMapper::Mapper.new(
        namespace: config.fetch(:namespace),
        dataset: SequelMapper::Dataset.new([]),
        factory: factories.fetch(name),
        serializer: serializer.call(config.fetch(:fields) + config.fetch(:associations).keys),
        fields: config.fetch(:fields),
        associations: config.fetch(:associations),
        mappers: registry,
      )
    }

    registry
  }

  let(:configs) {
    {
      users: {
        namespace: :users,
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
        },
      },

      comments: {
        namespace: :comments,
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
    }
  }
end
