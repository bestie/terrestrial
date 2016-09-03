require "spec_helper"

require "support/have_persisted_matcher"
require "support/object_store_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "terrestrial"

RSpec.describe "immutable domain objects" do
  include_context "object store setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  let(:user) { object_store[:users].where(id: "users/1").first }
  let(:user_clone) { user.clone }

  context "update the root node" do
    let(:modified_email) { "bestie+modified@gmail.com" }

    it "persists the change" do
      user_clone.email = modified_email
      user_store.save(user_clone)

      expect(datastore).to have_persisted(
        :users,
        hash_including(
          id: "users/1",
          email: modified_email,
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

    it "does not add the object to the graph" do
      user.posts + [new_post]

      expect(user.posts).not_to include(new_post)
    end

    it "persists the object" do
      new_posts = user.posts + [new_post]
      user_clone.posts = new_posts

      user_store.save(user_clone)

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
end
