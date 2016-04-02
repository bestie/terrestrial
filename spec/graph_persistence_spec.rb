require "spec_helper"

require "support/have_persisted_matcher"
require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "terrestrial"

RSpec.describe "Graph persistence" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  subject(:mapper) { mappers.fetch(:users) }

  let(:user) {
    mapper.where(id: "users/1").first
  }

  context "without associations" do
    let(:modified_email) { "bestie+modified@gmail.com" }

    it "saves the root object" do
      user.email = modified_email
      mapper.save(user)

      expect(datastore).to have_persisted(
        :users,
        hash_including(
          id: "users/1",
          email: modified_email,
        )
      )
    end

    it "doesn't send associated objects to the database as columns" do
      user.email = modified_email
      mapper.save(user)

      expect(datastore).not_to have_persisted(
        :users,
        hash_including(
          posts: anything,
        )
      )
    end

    # TODO move to a dirty tracking spec?
    context "when mutating entity fields in place" do
      it "saves the object" do
        user.email << "MUTATED"

        mapper.save(user)

        expect(datastore).to have_persisted(
          :users,
          hash_including(
            id: "users/1",
            email: /MUTATED$/,
          )
        )
      end
    end
  end

  context "modify shallow has many associated object" do
    let(:post) { user.posts.first }
    let(:modified_post_body) { "modified ur body" }

    it "saves the associated object" do
      post.body = modified_post_body
      mapper.save(user)

      expect(datastore).to have_persisted(
        :posts,
        hash_including(
          id: post.id,
          subject: post.subject,
          author_id: user.id,
          body: modified_post_body,
        )
      )
    end
  end

  context "modify deeply nested has many associated object" do
    let(:comment) {
      user.posts.first.comments.first
    }

    let(:modified_comment_body) { "body moving, body moving" }

    it "saves the associated object" do
      comment.body = modified_comment_body
      mapper.save(user)

      expect(datastore).to have_persisted(
        :comments,
        hash_including(
          {
            id: "comments/1",
            post_id: "posts/1",
            commenter_id: "users/1",
            body: modified_comment_body,
          }
        )
      )
    end
  end

  context "add a node to a has many association" do
    let(:new_post_attrs) {
      {
        id: "posts/neu",
        subject: "I am new",
        body: "new body",
        comments: [],
        categories: [],
        created_at: Time.now,
      }
    }

    let(:new_post) {
      Post.new(new_post_attrs)
    }

    it "adds the object to the graph" do
      user.posts.push(new_post)

      expect(user.posts).to include(new_post)
    end

    it "persists the object" do
      user.posts.push(new_post)

      mapper.save(user)

      expect(datastore).to have_persisted(
        :posts,
        hash_including(
          id: "posts/neu",
          author_id: user.id,
          subject: "I am new",
        )
      )
    end
  end

  context "delete an object from a has many association" do
    let(:post) { user.posts.first }

    it "delete the object from the graph" do
      user.posts.delete(post)

      expect(user.posts.map(&:id)).not_to include(post.id)
    end

    it "delete the object from the datastore on save" do
      user.posts.delete(post)
      mapper.save(user)

      expect(datastore).not_to have_persisted(
        :posts,
        hash_including(
          id: post.id,
        )
      )
    end
  end

  context "modify a many to many relationship" do
    let(:post)     { user.posts.first }

    context "delete a node" do
      it "mutates the graph" do
        category = post.categories.first
        post.categories.delete(category)

        expect(post.categories.map(&:id)).not_to include(category.id)
      end

      it "deletes the 'join table' record" do
        category = post.categories.first
        post.categories.delete(category)
        mapper.save(user)

        expect(datastore).not_to have_persisted(
          :categories_to_posts,
          {
            post_id: post.id,
            category_id: category.id,
          }
        )
      end

      it "does not delete the object" do
        category = post.categories.first
        post.categories.delete(category)
        mapper.save(user)

        expect(datastore).to have_persisted(
          :categories,
          hash_including(
            id: category.id,
          )
        )
      end
    end

    context "add a node" do
      let(:post_with_one_category) { user.posts.to_a.last }
      let(:new_category) { user.posts.first.categories.to_a.first }

      it "mutates the graph" do
        post_with_one_category.categories.push(new_category)

        expect(post_with_one_category.categories.map(&:id))
          .to match_array(["categories/1", "categories/2"])
      end

      it "persists the change" do
        post_with_one_category.categories.push(new_category)
        mapper.save(user)

        expect(datastore).to have_persisted(
          :categories_to_posts,
          {
            post_id: post_with_one_category.id,
            category_id: new_category.id,
          }
        )
      end
    end

    context "modify a node" do
      let(:category) { user.posts.first.categories.first }
      let(:modified_category_name) { "modified category" }

      it "mutates the graph" do
        category.name = modified_category_name

        expect(post.categories.first.name)
          .to eq(modified_category_name)
      end

      it "persists the change" do
        category.name = modified_category_name
        mapper.save(user)

        expect(datastore).to have_persisted(
          :categories,
          {
            id: category.id,
            name: modified_category_name,
          }
        )
      end
    end

    context "node loaded as root has undefined one to many association" do
      let(:post_mapper) { mappers[:posts] }
      let(:post) { post_mapper.where(id: "posts/1").first }

      it "persists the changes to the root node" do
        post.body = "modified body"

        post_mapper.save(post)

        expect(datastore).to have_persisted(
          :posts,
          hash_including(
            id: "posts/1",
            body: "modified body",
          )
        )
      end

      it "does not overwrite unused foreign key" do
        post.body = "modified body"

        post_mapper.save(post)

        expect(datastore).to have_persisted(
          :posts,
          hash_including(
            id: "posts/1",
            author_id: "users/1",
          )
        )
      end
    end
  end

  context "when a save operation fails (some object is not persistable)" do
    let(:unpersistable_object) { ->() { } }

    it "rolls back the transaction" do
      pre_change = datastore[:users].to_a.map(&:to_a).sort

      begin
        user.first_name = "this will be rolled back"
        user.posts.first.subject = unpersistable_object

        mapper.save(user)
      rescue Sequel::Error
      end

      post_change = datastore[:users].to_a.map(&:to_a).sort

      expect(pre_change).to eq(post_change)
    end
  end
end
