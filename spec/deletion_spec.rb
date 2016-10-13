require "spec_helper"

require "support/object_store_setup"
require "support/seed_data_setup"
require "support/have_persisted_matcher"
require "terrestrial"

RSpec.describe "Deletion" do
  include_context "object store setup"
  include_context "seed data setup"

  subject(:user_store) { object_store[:users] }

  let(:user) {
    user_store.where(id: "users/1").first
  }

  let(:reloaded_user) {
    user_store.where(id: "users/1").first
  }

  describe "Deleting the root" do
    it "deletes the root object" do
      user_store.delete(user, cascade: true)

      expect(datastore).not_to have_persisted(
        :users,
        hash_including(id: "users/1")
      )
    end

    context "when much of the graph has been loaded" do
      before do
        user.posts.flat_map(&:comments)
      end

      it "deletes the root object" do
        user_store.delete(user)

        expect(datastore).not_to have_persisted(
          :users,
          hash_including(id: "users/1")
        )
      end

      it "does not delete the child objects" do
        expect {
          user_store.delete(user)
        }.not_to change { [datastore[:posts], datastore[:comments]].map(&:count) }
      end
    end

    # context "deleting multiple" do
    #   it "is not currently supported"
    # end
  end

  describe "Deleting a child object (one to many)" do
    let(:post) {
      user.posts.find { |post| post.id == "posts/1" }
    }

    it "deletes the specified node" do
      user.posts.delete(post)
      user_store.save(user)

      expect(datastore).not_to have_persisted(
        :posts,
        hash_including(id: "posts/1")
      )
    end

    it "does not delete the parent object" do
      user.posts.delete(post)
      user_store.save(user)

      expect(datastore).to have_persisted(
        :users,
        hash_including(id: "users/1")
      )
    end

    it "does not delete the sibling objects" do
      user.posts.delete(post)
      user_store.save(user)

      expect(reloaded_user.posts.count).to be > 0
    end

    it "does not cascade delete" do
      expect {
        user.posts.delete(post)
        user_store.save(user)
      }.not_to change {
        datastore[:comments].map { |r| r.fetch(:id) }
      }
    end
  end
end
