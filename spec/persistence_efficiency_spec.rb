require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"

RSpec.describe "Graph persistence efficiency" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  let(:mapper) { user_mapper }
  let(:user_query) { mapper.where(id: "users/1") }
  let(:user) { user_query.first }

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

    it "performs 1 update" do
      expect {
        mapper.save(user)
      }.to change { query_counter.update_count }.by(1)
    end

    it "performs 0 deletes" do
      expect {
        mapper.save(user)
      }.to change { query_counter.delete_count }.by(0)
    end

    it "performs 0 additional reads" do
      expect {
        mapper.save(user)
      }.to change { query_counter.read_count }.by(0)
    end
  end

  context "when loading many nodes of the graph" do
    let(:post) {
      user.posts.first
    }

    context "and modifying an intermediate node" do
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
      let(:comment) { post.comments.first }

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
      let(:comment) { post.comments.first }

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
          mapper.eager_load(:posts => []).all.map { |user|
            [user.id, user.posts.map(&:id)]
          }
        }.to change { query_counter.read_count }.by(2)
      end
    end

    # mapper.eager_load([:posts, [:comments, [:author]]])

    context "with nested has many" do
      it "performs 1 read per table rather than n + 1" do
        expect {
          user_query
            .eager_load(:posts => { :comments => [] })
            .first
            .posts
            .map { |post| post.comments.map(&:id) }
        }.to change { query_counter.read_count }.by(3)
      end
    end

    context "with has many and belongs to" do
      it "performs 1 read per table rather than n + 1" do
        expect {
          user_query
            .eager_load(:posts => { :comments => { :commenter => [] }})
            .flat_map { |u| u.posts.to_a }
            .flat_map { |p| p.comments.to_a }
            .flat_map { |c| c.commenter.id }
        }.to change { query_counter.read_count }.by(4)
      end
    end

    context "for has many to has many through" do
      it "performs 1 read per table rather than n + 1" do
        expect {
          user_query
            .eager_load(:posts => { :categories => [] })
            .flat_map { |u| u.posts.to_a }
            .flat_map { |p| p.categories.to_a }
            .flat_map { |c| c.id }
        }.to change { query_counter.read_count }.by(3)
      end
    end

    context "for has many through to has many" do
      it "performs 1 read per table rather than n + 1" do
        expect {
          user_query
            .eager_load(:posts => { :categories => { :posts => [] }})
            .flat_map { |u| u.posts.to_a }
            .flat_map { |p| p.categories.to_a }
            .flat_map { |c| c.posts.to_a }
        }.to change { query_counter.read_count }.by(4)
      end
    end
  end

  after do |example|
    query_counter.show_queries if example.exception
  end
end
