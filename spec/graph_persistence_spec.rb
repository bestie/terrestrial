require "spec_helper"

require "support/have_persisted_matcher"
require "support/object_store_setup"
require "support/seed_data_setup"
require "terrestrial"

RSpec.describe "Graph persistence" do
  include_context "object store setup"
  include_context "seed data setup"

  subject(:user_store) { object_store.fetch(:users) }

  let(:user) {
    user_store.where(id: "users/1").first
  }

  context "without associations" do
    let(:modified_email) { "hasel+modified@gmail.com" }

    it "saves the root object" do
      user.email = modified_email
      user_store.save(user)

      expect(datastore).to have_persisted(
        :users,
        hash_including(
          id: "users/1",
          email: modified_email,
        )
      )
    end

    context "when mutating an entity's fields in place" do
      it "updates the row with new, mutated values" do
        user.email << "MUTATED"

        user_store.save(user)

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
      user_store.save(user)

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
      user_store.save(user)

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
        author: nil,
        subject: "I am new",
        body: "new body",
        comments: [],
        categories: [],
        created_at: Time.now,
        updated_at: Time.now,
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

      user_store.save(user)

      expect(datastore).to have_persisted(
        :posts,
        hash_including(
          id: "posts/neu",
          author_id: user.id,
          subject: "I am new",
        )
      )
    end

    context "when the collection is not loaded until the new object is persisted" do
      it "is consistent with the datastore" do
        user.posts.push(new_post)

        user_store.save(user)

        expect(user.posts.to_a.map(&:id)).to eq(
          ["posts/1", "posts/2", "posts/neu"]
        )
      end
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
      user_store.save(user)

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
        user_store.save(user)

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
        user_store.save(user)

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
        user_store.save(user)

        expect(datastore).to have_persisted(
          :categories_to_posts,
          {
            post_id: post_with_one_category.id,
            category_id: new_category.id,
          }
        )
      end
    end

    context "duplicate a node" do
      let(:post_with_one_category) { user.posts.to_a.last }

      # Spoiler alert: it does mutate the graph
      #
      # Feature?: The posts <=> category relationship because unique when persisted
      # because there are no indexes on the `categories_to_posts` table making
      # the combination of foreign keys a de facto primary key.
      #
      # If there was an additional primary key id field without a unique index
      # this would not be the case.
      #
      # It would be nice if the collection proxy for posts <=> categories was a
      # variant that behaved like set. Unfortunately uniqueness can only be
      # determined by the user-defind objects' identities as the proxy would
      # not have access to datastore ids.
      #
      # Mappings are available when the proxy is constructed so this is
      # possible but awkward.
      xit "does not mutate the graph" do
        existing_category = post_with_one_category.categories.first
        post_with_one_category.categories.push(existing_category)

        expect(post_with_one_category.categories.map(&:id))
          .to eq(["categories/2"])
      end

      it "does not persist the change" do
        existing_category = post_with_one_category.categories.first
        post_with_one_category.categories.push(existing_category)

        user_store.save(user)

        expect(
          datastore[:categories_to_posts]
            .where(:post_id => post_with_one_category.id)
            .count
        ).to eq(1)
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
        user_store.save(user)

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
      let(:post_store) { object_store[:posts] }
      let(:post) { post_store.where(id: "posts/1").first }

      it "persists the changes to the root node" do
        post.body = "modified body"

        post_store.save(post)

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

        post_store.save(post)

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

  context "when a many to one association is nil" do
    context "when the object does not have a reference to its parent" do
      it "populates that association with a nil" do
        post = Post.new(
          id: "posts/orphan",
          author: nil,
          subject: "Nils gonna getcha",
          body: "",
          created_at: Time.parse("2015-09-05T15:00:00+01:00"),
          updated_at: Time.parse("2015-09-05T15:00:00+01:00"),
          categories: [],
          comments: [],
        )

        object_store[:posts].save(post)

        expect(datastore).to have_persisted(
          :posts,
          hash_including(
            id: "posts/orphan",
            author_id: nil,
          )
        )
      end
    end

    context "when an existing partent object reference is set to nil" do
      it "does not orphan the object and sets the foreign key according to position in the object graph" do
        comment = user
          .posts
          .flat_map(&:comments)
          .detect { |c| c.id == "comments/1" }

        comment.commenter = nil

        user_store.save(user)

        expect(datastore).to have_persisted(
          :comments,
          hash_including(
            id: "comments/1",
            commenter_id: "users/1",
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

        user_store.save(user)
      rescue Object => e
      end

      expect(e).to be_a(Terrestrial::Error)

      post_change = datastore[:users].to_a.map(&:to_a).sort

      expect(pre_change).to eq(post_change)
    end
  end
end
