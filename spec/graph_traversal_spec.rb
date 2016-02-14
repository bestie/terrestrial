require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"

RSpec.describe "Graph traversal" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  describe "associations" do
    subject(:mapper) { user_mapper }

    let(:user_query) {
      mapper.where(id: "users/1")
    }

    let(:user) { user_query.first }

    it "finds data via the storage adapter" do
      expect(user_query.count).to eq(1)
    end

    it "maps the raw data from the store into domain objects" do
      expect(user_query.first.id).to eq("users/1")
      expect(user_query.first.first_name).to eq("Hansel")
    end

    it "handles has_many associations" do
      post = user.posts.first

      expect(post.subject).to eq("Biscuits")
    end

    it "handles nested has_many associations" do
      expect(
        user
          .posts.first
          .comments.first
          .body
      ).to eq("oh noes")
    end

    describe "lazy loading" do
      let(:post_factory) { double(:post_factory, call: nil) }

      it "loads has many associations lazily" do
        posts = user_query.first.posts

        expect(post_factory).not_to have_received(:call)
      end
    end

    it "maps belongs to associations" do
      post = user.posts.first
      comment = post.comments.first

      expect(comment.commenter.id).to eq("users/1")
    end

    describe "identity map" do
      it "always returns (a proxy of) the same object for a given id" do
        post = user.posts.first
        comment = post.comments.first

        expect(comment.commenter.__getobj__)
          .to be(user)
      end
    end

    it "maps deeply nested belongs to associations" do
      expect(user_query.first.posts.first.comments.first.commenter.id)
        .to eq("users/1")
    end

    it "maps has many to many associations as has many through" do
      expect(user_query.first.posts.first.categories.map(&:id))
        .to match_array(["categories/1", "categories/2"])

      expect(user_query.first.posts.first.categories.to_a.last.posts.map(&:id))
        .to match_array(["posts/1", "posts/2", "posts/3"])
    end

    describe "eager_loading" do
      it "returns the expected objects" do
        expect(
          user_query
            .eager_load(:posts => { :categories => { :posts => [] }})
            .flat_map(&:posts)
            .flat_map(&:categories)
            .map(&:posts)
            .map { |collection| collection.map(&:id) }
        ).to eq([["posts/1"]] + [["posts/1", "posts/2", "posts/3"]] * 2)
      end

      context "when traversing beyond the eager loaded data" do
        it "returns the expected objects" do
          expect(
            user_query
              .eager_load(:posts => { :categories => { :posts => [] }})
              .flat_map(&:posts)
              .flat_map(&:categories)
              .flat_map(&:posts)
              .flat_map(&:categories)
              .flat_map(&:posts)
              .flat_map(&:categories)
              .uniq
              .map(&:id)
          ).to eq([
            "categories/1",
            "categories/2",
            "categories/3",
            "categories/4",
          ])
        end
      end
    end
  end
end
