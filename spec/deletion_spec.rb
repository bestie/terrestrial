require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "support/have_persisted_matcher"
require "sequel_mapper"

RSpec.describe "Deletion" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  subject(:mapper) { user_mapper }

  let(:user) {
    mapper.where(id: "users/1").first
  }

  let(:reloaded_user) {
    mapper.where(id: "users/1").first
  }

  describe "Deleting the root" do
    it "deletes the root object" do
      mapper.delete(user, cascade: true)

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
        mapper.delete(user)

        expect(datastore).not_to have_persisted(
          :users,
          hash_including(id: "users/1")
        )
      end

      it "does not delete the child objects" do
        expect {
          mapper.delete(user)
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
      mapper.save(user)

      expect(datastore).not_to have_persisted(
        :posts,
        hash_including(id: "posts/1")
      )
    end

    it "does not delete the parent object" do
      user.posts.delete(post)
      mapper.save(user)

      expect(datastore).to have_persisted(
        :users,
        hash_including(id: "users/1")
      )
    end

    it "does not delete the sibling objects" do
      user.posts.delete(post)
      mapper.save(user)

      expect(reloaded_user.posts.count).to be > 0
    end

    it "does not cascade delete" do
      expect {
        user.posts.delete(post)
        mapper.save(user)
      }.not_to change {
        datastore[:comments].map { |r| r.fetch(:id) }
      }
    end
  end
end
