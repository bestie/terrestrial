require "support/mock_sequel"
require "sequel_mapper/struct_factory"

module SequelMapper
  module DatabaseFixture
    include SequelTestSupport

    # A little hack so these let blocks from an RSpec example don't have
    # to change
    def self.let(name, &block)
      define_method(name) {
        instance_variable_get("@#{name}") or
          instance_variable_set("@#{name}", instance_eval(&block))
      }
    end

    User = Struct.new(:id, :first_name, :last_name, :email, :posts, :toots)
    Post = Struct.new(:id, :author, :subject, :body, :comments, :categories)
    Comment = Struct.new(:id, :post, :commenter, :body)
    Category = Struct.new(:id, :name, :posts)
    Toot = Struct.new(:id, :tooter, :body, :tooted_at)

    let(:query_counter) {
      SequelTestSupport::QueryCounter.new
    }

    let(:datastore) {
      db_connection.tap { |db|
        load_fixture_data(db)
        db.loggers << query_counter
      }
    }

    def mapper_fixture
      SequelMapper.mapper(
        top_level_namespace: :users,
        datastore: datastore,
        relation_mappings: relation_mappings,
      )
    end

    def load_fixture_data(datastore)
      tables.each do |table, rows|

        datastore.drop_table?(table)

        datastore.create_table(table) do
          rows.first.keys.each do |column|
            String column
          end
        end

        rows.each do |row|
          datastore[table].insert(row)
        end
      end
    end

    let(:tables) {
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
          comment_2_data,
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
        toots: [
          # Toot ordering is inconsistent for scope testing.
          toot_2_data,
          toot_1_data,
          toot_3_data,
        ],
      }
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
            toots: {
              relation_name: :toots,
              foreign_key: :tooter_id,
              order_by: {
                columns: [:tooted_at],
                direction: :desc,
              },
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
        },
        toots: {
          columns: [
            :id,
            :tooter_id,
            :body,
            :tooted_at,
          ],
          factory: toot_factory,
          belongs_to: {
            tooter: {
              relation_name: :users,
              foreign_key: :tooter_id,
            },
          },
        },
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

    let(:toot_factory){
      SequelMapper::StructFactory.new(Toot)
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

    let(:comment_2_data) {
      {
        id: "comment/2",
        post_id: "post/1",
        commenter_id: "user/1",
        body: "You are so LOL",
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

    let(:category_3_data) {
      {
        id: "category/3",
        name: "ugly",
      }
    }

    let(:toot_1_data) {
      {
        id: "toot/1",
        tooter_id: "user/1",
        body: "Armistice toots",
        tooted_at: Time.parse("2014-11-11 11:11:00 UTC").iso8601,
      }
    }
    let(:toot_2_data) {
      {
        id: "toot/2",
        tooter_id: "user/1",
        body: "Tooting every second",
        tooted_at: Time.parse("2014-11-11 11:11:01 UTC").iso8601,
      }
    }

    let(:toot_3_data) {
      {
        id: "toot/3",
        tooter_id: "user/1",
        body: "Join me in a minutes' toots",
        tooted_at: Time.parse("2014-11-11 11:11:02 UTC").iso8601,
      }
    }
  end
end
