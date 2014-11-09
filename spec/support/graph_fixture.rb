require "support/mock_sequel"

module SequelMapper
  module GraphFixture

    # A little hack so these let blocks from an RSpec example don't have
    # to change
    def self.let(name, &block)
      define_method(name) {
        instance_variable_get("@#{name}") or
          instance_variable_set("@#{name}", instance_eval(&block))
      }
    end

    User = Struct.new(:id, :first_name, :last_name, :email, :posts)
    Post = Struct.new(:id, :author, :subject, :body, :comments, :categories)
    Comment = Struct.new(:id, :post, :commenter, :body)
    Category = Struct.new(:id, :name, :posts)

    let(:datastore) {
      SequelMapper::MockSequel.new(
        {
          users: [
            user_1_data,
            user_2_data,
            user_3_data,
          ],
          posts: [
            post_1_data,
            post_2_data,
          ],
          comments: [
            comment_1_data,
          ],
          categories: [
            category_1_data,
            category_2_data,
          ],
          categories_to_posts: [
            {
              post_id: post_1_data.fetch(:id),
              category_id: category_1_data.fetch(:id),
            },
            {
              post_id: post_1_data.fetch(:id),
              category_id: category_2_data.fetch(:id),
            },
            {
              post_id: post_2_data.fetch(:id),
              category_id: category_2_data.fetch(:id),
            },
          ],
        }
      )
    }

    let(:relation_mappings) {
      {
        users: {
          columns: [
            :id,
            :first_name,
            :last_name,
            :email,
          ],
          factory: user_factory,
          has_many: {
            posts: {
              relation_name: :posts,
              foreign_key: :author_id,
            },
          },
          # TODO: maybe combine associations like this
          # has_many_through: {
          #   categories_posted_in: {
          #     through_association: [ :posts, :categories ]
          #   }
          # }
        },
        posts: {
          columns: [
            :id,
            :author_id,
            :subject,
            :body,
          ],
          factory: post_factory,
          has_many: {
            comments: {
              relation_name: :comments,
              foreign_key: :post_id,
            },
          },
          has_many_through: {
            categories: {
              through_relation_name: :categories_to_posts,
              relation_name: :categories,
              foreign_key: :post_id,
              association_foreign_key: :category_id,
            }
          },
          belongs_to: {
            author: {
              relation_name: :users,
              foreign_key: :author_id,
            },
          },
        },
        comments: {
          columns: [
            :id,
            :post_id,
            :commenter_id,
            :body,
          ],
          factory: comment_factory,
          belongs_to: {
            commenter: {
              relation_name: :users,
              foreign_key: :commenter_id,
            },
          },
        },
        categories: {
          columns: [
            :id,
            :name,
          ],
          factory: category_factory,
          has_many_through: {
            posts: {
              through_relation_name: :categories_to_posts,
              relation_name: :posts,
              foreign_key: :category_id,
              association_foreign_key: :post_id,
            }
          },
        }
      }
    }

    let(:user_factory){
      SequelMapper::StructFactory.new(User)
    }

    let(:post_factory){
      SequelMapper::StructFactory.new(Post)
    }

    let(:comment_factory){
      SequelMapper::StructFactory.new(Comment)
    }

    let(:category_factory){
      SequelMapper::StructFactory.new(Category)
    }

    let(:user_1_data) {
      {
        id: "user/1",
        first_name: "Stephen",
        last_name: "Best",
        email: "bestie@gmail.com",
      }
    }

    let(:user_2_data) {
      {
        id: "user/2",
        first_name: "Hansel",
        last_name: "Trickett",
        email: "hansel@gmail.com",
      }
    }

    let(:user_3_data) {
      {
        id: "user/3",
        first_name: "Jasper",
        last_name: "Trickett",
        email: "jasper@gmail.com",
      }
    }

    let(:post_1_data) {
      {
        id: "post/1",
        author_id: "user/1",
        subject: "Object mapping",
        body: "It is often tricky",
      }
    }

    let(:post_2_data) {
      {
        id: "post/2",
        author_id: "user/1",
        subject: "Object mapping part 2",
        body: "Lazy load all the things!",
      }
    }

    let(:comment_1_data) {
      {
        id: "comment/1",
        post_id: "post/1",
        commenter_id: "user/2",
        body: "Trololol",
      }
    }

    let(:category_1_data) {
      {
        id: "category/1",
        name: "good",
      }
    }

    let(:category_2_data) {
      {
        id: "category/2",
        name: "bad",
      }
    }
  end
end
