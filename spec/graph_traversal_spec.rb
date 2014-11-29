require "spec_helper"

require "sequel_mapper"
require "support/graph_fixture"

RSpec.describe "Graph traversal" do
  include SequelMapper::GraphFixture

  describe "assocaitions" do
    subject(:graph) {
      SequelMapper::Graph.new(
        top_level_namespace: :users,
        datastore: datastore,
        relation_mappings: relation_mappings,
      )
    }

    let(:user_query) {
      graph.where(id: "user/1")
    }

    it "finds data via the storage adapter" do
      expect(user_query.count).to be 1
    end

    it "maps the raw data from the store into domain objects" do
      expect(user_query.first.id).to eq("user/1")
      expect(user_query.first.first_name).to eq("Stephen")
    end

    it "handles has_many associations" do
      expect(user_query.first.posts.first.subject)
        .to eq("Object mapping")
    end

    it "handles nested has_many associations" do
      expect(
        user_query.first
          .posts.first
          .comments.first
          .body
      ).to eq("Trololol")
    end

    describe "lazy loading" do
      let(:post_factory) { double(:post_factory, call: nil) }

      it "loads has many associations lazily" do
        posts = user_query.first.posts

        expect(post_factory).not_to have_received(:call)
      end
    end

    it "maps belongs to assocations" do
      expect(user_query.first.posts.first.author.id)
        .to eq("user/1")
    end

    describe "identity map" do
      it "always returns (a proxy of) the same object for a given id" do
        expect(user_query.first.posts.first.author.__getobj__)
          .to be(user_query.first)
      end
    end

    it "maps deeply nested belongs to assocations" do
      expect(user_query.first.posts.first.comments.first.commenter.id)
        .to eq("user/2")
    end

    it "maps has many to many associations as has many through" do
      expect(user_query.first.posts.first.categories.map(&:id))
        .to match_array(["category/1", "category/2"])

      expect(user_query.first.posts.first.categories.to_a.last.posts.map(&:id))
        .to match_array(["post/1", "post/2"])
    end
  end
end
