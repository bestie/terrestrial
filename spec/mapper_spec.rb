require "spec_helper"

require "mapper"

RSpec.describe "Object mapping" do

  User = Struct.new(:id, :first_name, :last_name, :email, :posts)
  Post = Struct.new(:id, :author_id, :subject, :body, :comments)
  Comment = Struct.new(:id, :post_id, :commenter_id, :body)

  describe "Straight trivial mapping" do
    subject(:mapper) {
      Mapper.new(
        top_level_namespace: :users,
        datastore: datastore,
        relation_mappings: relation_mappings,
      )
    }

    let(:datastore) {
      Mapper::MockSequel.new(
        {
          users: [
            user_1_data,
            user_2_data,
          ],
          posts: [
            post_1_data,
          ],
          comments: [
            comment_1_data,
          ],
        }
      )
    }

    let(:relation_mappings) {
      {
        users: {
          factory: user_factory,
          has_many: {
            posts: {
              relation_name: :posts,
              foreign_key: :author_id,
            },
          },
        },
        posts: {
          factory: post_factory,
          has_many: {
            comments: {
              relation_name: :comments,
              foreign_key: :commenter_id,
            },
          },
        },
        comments: {
          factory: comment_factory,
        }
      }
    }

    let(:user_factory){
      Mapper::StructFactory.new(User)
    }

    let(:post_factory){
      Mapper::StructFactory.new(Post)
    }

    let(:comment_factory){
      Mapper::StructFactory.new(Comment)
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

    let(:post_1_data) {
      {
        id: "post/1",
        author_id: "user/1",
        subject: "Object mapping",
        body: "It is often tricky",
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

    let(:user_query) {
      mapper.where(id: "user/1")
    }

    it "finds data via the storage adapter" do
      expect(user_query.count).to be 1
    end

    it "maps the raw data from the store into domain objects" do
      expect(user_query.fetch(0).id).to eq("user/1")
      expect(user_query.fetch(0).first_name).to eq("Stephen")
    end

    it "handles has_many associations" do
      expect(user_query.fetch(0).posts.first.subject)
        .to eq("Object mapping")
    end

    it "handles nested has_many associations" do
      expect(user_query.fetch(0).posts.first.comments.body)
        .to eq("Trololol")
    end
  end
end
