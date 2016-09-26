require "spec_helper"

require "support/object_store_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "terrestrial"

RSpec.describe "Object identity" do
  include_context "object store setup"
  include_context "seed data setup"

  subject(:user_store) { object_store.fetch(:users) }

  let(:user) { user_store.where(id: "users/1").first }
  let(:post) { user.posts.first }

  context "when using arbitrary where query" do
    it "returns the same object for a row's primary key" do
      expect(
        user.posts.where(id: post.id).first
      ).to be(post)
    end
  end

  context "when traversing deep into the graph" do
    context "via has many through" do
      it "returns the same object for a row's primary key" do
        expect(
          user.posts.first.categories.first.posts
            .find { |cat_post| cat_post.id == post.id }
        ).to be(post)
      end
    end

    context "via a belongs to" do
      it "returns the same object for a row's primary once loaded" do
        # TODO: Add another method to avoid using #__getobj__
        expect(
          user.posts.first.comments
            .find { |comment| comment.commenter.id == user.id }
            .commenter
            .__getobj__
        ).to be(user)
      end
    end

    context "when eager loading" do
      let(:user_query) { user_store.where(id: "users/1") }

      let(:eager_category) {
        user_query
          .eager_load(:posts => { :categories => { :posts => [] }})
          .first
          .posts
          .first
          .categories
          .first
      }

      it "returns the same object for a row's primary once loaded" do
        expect(
          eager_category
            .posts
            .find { |cat_post| cat_post.id == post.id }
        ).to be(post)
      end
    end
  end
end
