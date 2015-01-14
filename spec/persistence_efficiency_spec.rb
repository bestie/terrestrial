
require "spec_helper"

require "sequel_mapper"
require "support/database_fixture"

RSpec.describe "Graph persistence" do
  include SequelMapper::DatabaseFixture

  subject(:mapper) { mapper_fixture }

  let(:user) {
    mapper.where(id: "user/1").first
  }

  context "when modifying the root node" do
    let(:modified_email) { "modified@example.com" }

    context "and only the root node" do
      before do
        user.email = modified_email
      end

      it "performs 1 update" do
        expect {
          mapper.save(user)
        }.to change { query_counter.update_count }.by(1)
      end
    end
  end

  context "when modifying a directly associated (has many) object" do
    let(:modified_post_subject) { "modified post subject" }

    before do
      user.posts.first.subject = modified_post_subject
    end

    it "performs 1 updates" do
      expect {
        mapper.save(user)
      }.to change { query_counter.update_count }.by(1)
    end
  end

  context "when loading many nodes of the graph" do
    let(:leaf_node) {
      user.posts.first.comments.first
    }

    before do
      leaf_node
    end

    context "and modifying an intermediate node" do
      let(:post) { leaf_node.post }

      before do
        post.subject = "MODIFIED"
      end

      it "performs 1 write" do
        expect {
          mapper.save(user)
        }.to change { query_counter.update_count }.by(1)
      end
    end

    context "and modifying a leaf node" do
      let(:comment) { leaf_node }

      before do
        comment.body = "UPDATED!"
      end

      it "performs 1 update" do
        expect {
          mapper.save(user)
        }.to change { query_counter.update_count }.by(1)
      end
    end

    context "and modifying both a leaf and intermediate node" do
      let(:post) { leaf_node.post }
      let(:comment) { leaf_node }

      before do
        comment.body = "UPDATED!"
        post.subject = "MODIFIED"
      end

      it "performs 2 updates" do
        expect {
          mapper.save(user)
        }.to change { query_counter.update_count }.by(2)
      end
    end
  end

  context "when modifying a many to many association" do
    let(:post) { user.posts.first }
    let(:category) { post.categories.first }

    before do
      category.name = "UPDATED"
    end

    it "performs 1 write" do
        expect {
          mapper.save(user)
        }.to change { query_counter.update_count }.by(1)
    end
  end

  context "eager loading" do
    context "on root node" do
      it "performs 1 read per table rather than n + 1" do
        expect {
          mapper.eager_load(:posts).map(&:id)
        }.to change { query_counter.read_count }.by(2)
      end
    end

    context "with nested has many" do
      it "performs 1 read per table rather than n + 1" do
        expect {
          user.posts.eager_load(:comments).map { |post| post.comments.map(&:id) }
        }.to change { query_counter.read_count }.by(3)
      end
    end

    context "with has many and belongs to" do
      it "performs 1 read per table rather than n + 1" do
        expect {
          user.posts.first
            .comments.eager_load(:commenter)
            .map(&:commenter)
            .map(&:id)
        }.to change { query_counter.read_count }.by(4)
      end
    end

    context "for has many to has many through" do
      it "performs 1 read per table rather than n + 1" do
        expect {
          user.posts.eager_load(:categories)
            .map(&:categories)
            .flat_map { |cats| cats.map(&:id) }
        }.to change { query_counter.read_count }.by(3)
      end
    end

    context "for has many through to has many" do
      it "performs 1 read per table rather than n + 1" do
        expect {
          user.posts.first.categories.eager_load(:posts)
            .map(&:posts)
            .flat_map { |posts| posts.map(&:id) }
        }.to change { query_counter.read_count }.by(4)
      end
    end
  end

  describe "optimized #first" do
    context "root level mapper" do
    end

    context "associations" do
      before { user }

      it "loads only one row from the datastore" do
        expect {
          user.posts.first
        }.to change { dirty_map.length }.by(1)
      end
    end
  end

  after do |ex|
    query_counter.show_queries if ex.exception
  end
end
