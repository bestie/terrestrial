require "spec_helper"

require "support/object_store_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "terrestrial"

RSpec.describe "Graph persistence efficiency" do
  include_context "object store setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  let(:user_store) { object_store[:users] }
  let(:user_query) { user_store.where(id: "users/1") }
  let(:user) { user_query.first }

  context "when modifying the root node" do
    let(:modified_email) { "modified@example.com" }

    context "and only the root node" do
      before do
        user.email = modified_email
      end

      it "performs 1 update" do
        expect {
          user_store.save(user)
        }.to change { query_counter.update_count }.by(1)
      end

      it "sends only the updated fields to the datastore" do
        user_store.save(user)
        update_sql = query_counter.updates.last

        expect(update_sql).to eq(
          %{UPDATE "users" SET "email" = '#{modified_email}' WHERE ("id" = '#{user.id}')}
        )
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
        user_store.save(user)
      }.to change { query_counter.update_count }.by(1)
    end

    it "performs 0 deletes" do
      expect {
        user_store.save(user)
      }.to change { query_counter.delete_count }.by(0)
    end

    it "performs 0 additional reads" do
      expect {
        user_store.save(user)
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
          user_store.save(user)
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
          user_store.save(user)
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
          user_store.save(user)
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
          user_store.save(user)
        }.to change { query_counter.update_count }.by(1)
    end
  end

  context "eager loading" do
    context "on root node" do
      it "performs 1 read per table rather than n + 1" do
        expect {
          user_store.eager_load(:posts => []).all.map { |user|
            [user.id, user.posts.map(&:id)]
          }
        }.to change { query_counter.read_count }.by(2)
      end
    end

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
            .flat_map(&:posts)
            .flat_map(&:comments)
            .flat_map(&:commenter)
        }.to change { query_counter.read_count }.by(4)
      end
    end

    context "for has many to has many through" do
      it "performs 1 read per table (including join table) rather than n + 1" do
        expect {
          user_query
            .eager_load(:posts => { :categories => [] })
            .flat_map(&:posts)
            .flat_map(&:categories)
            .flat_map(&:id)
        }.to change { query_counter.read_count }.by(4)
      end
    end

    context "for has many through to has many" do
      it "performs 1 read per table (includiing join table) rather than n + 1" do
        expect {
          user_query
            .eager_load(:posts => { :categories => { :posts => [] }})
            .flat_map(&:posts)
            .flat_map(&:categories)
            .flat_map(&:posts)
        }.to change { query_counter.read_count }.by(6)
      end
    end

    context "eager load multiple associations at same level" do
      it "performs 1 read per table (includiing join table) rather than n + 1" do
        expect {
          posts = user_query
            .eager_load(:posts => { :comments => {}, :categories => {} })
            .flat_map(&:posts)

          categories = posts.flat_map(&:categories)
          comments = posts.flat_map(&:comments)
        }.to change { query_counter.read_count }.by(5)
      end
    end

    context "mixed eager and lazy loading" do
      it "lazy data can still be loaded while eager data remains efficient" do
        eager_queries = 6
        lazy_comment_queries = 3

        expect {
          user_query
            .eager_load(:posts => { :categories => { :posts => [] }})
            .flat_map(&:posts)
            .flat_map(&:categories)
            .flat_map(&:posts)
            .flat_map(&:comments)
        }.to change {
          query_counter.read_count
        }.by(eager_queries + lazy_comment_queries)
      end
    end
  end

  after do |example|
    query_counter.show_queries if example.exception
  end
end
