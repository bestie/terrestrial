require "spec_helper"

require "sequel_mapper"
require "support/graph_fixture"

RSpec.describe "Proxying associations" do
  include SequelMapper::GraphFixture

  context "of type `has_many`" do
    subject(:graph) {
      SequelMapper::Graph.new(
        top_level_namespace: :users,
        datastore: datastore,
        relation_mappings: relation_mappings,
      )
    }

    let(:user) {
      graph.where(id: "user/1").first
    }

    let(:posts) { user.posts }

    def identity
      ->(x){x}
    end

    describe "limiting datastore reads" do
      context "when loading the root node" do
        it "only performs one read" do
          user

          expect(datastore.read_count).to eq(1)
        end
      end

      context "when getting a reference to an association proxy" do
        before { user }

        it "does no additional reads" do
          expect{
            user.posts
          }.to change { datastore.read_count }.by(0)
        end
      end

      context "when iteratiing over a has many association" do
        before { posts }

        it "does a single additional read for the assocation collection" do
          expect {
            user.posts.map(&identity)
          }.to change { datastore.read_count }.by(1)
        end
      end

      context "when getting a reference to a many to many assocation" do
        before { post }

        let(:post) { user.posts.first }

        it "does no additional reads" do
          expect {
            post.categories
          }.to change { datastore.read_count }.by(0)
        end
      end

      context "when iterating over a many to many assocation" do
        before { category_count }

        let(:categories) { user.posts.first.categories }
        let(:category_count) { categories.count }

        it "does 2n+1 reads" do
          expect {
            categories.map(&identity)
          }.to change { datastore.read_count }.by( 2*category_count + 1 )
        end
      end
    end
  end
end
