require "spec_helper"

require "sequel_mapper"
require "support/database_fixture"

RSpec.describe "Object identity" do
  include SequelMapper::DatabaseFixture

  subject(:mapper) { mapper_fixture }

  let(:user) { mapper.where(id: "user/1").first }
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
      it "returns the same object for a row's primary once loaded" do
        expect(
          user.posts.first.categories.eager_load(:posts).first.posts
            .find { |cat_post| cat_post.id == post.id }
        ).to be(post)
      end
    end
  end
end
