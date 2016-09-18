require "spec_helper"
require "support/object_store_setup"
require "support/sequel_persistence_setup"
require "support/have_persisted_matcher"

RSpec.describe "Persist a new graph in empty datastore" do
  include_context "object store setup"
  include_context "sequel persistence setup"

  context "given a graph of new objects" do
    it "persists the root node" do
      object_store[:users].save(hansel)

      expect(datastore).to have_persisted(:users, {
        id: hansel.id,
        first_name: hansel.first_name,
        last_name: hansel.last_name,
        email: hansel.email,
      })
    end

    it "persists one to many related nodes 1 level deep" do
      object_store[:users].save(hansel)

      expect(datastore).to have_persisted(:posts, hash_including(
        id: "posts/1",
        subject: "Biscuits",
        body: "I like them",
        author_id: "users/1",
      ))

      expect(datastore).to have_persisted(:posts, hash_including(
        id: "posts/2",
        subject: "Sleeping",
        body: "I do it three times purrr day",
        author_id: "users/1",
      ))
    end

    context "deep node with two foreign keys" do
      it "persists the node with both foreign keys" do
        object_store[:users].save(hansel)

        expect(datastore).to have_persisted(:comments, {
          id: "comments/1",
          body: "oh noes",
          post_id: "posts/1",
          commenter_id: "users/1",
        })
      end
    end

    it "persists many to many related nodes" do
      object_store[:users].save(hansel)

      expect(datastore).to have_persisted(:categories, {
        id: "categories/1",
        name: "Cat biscuits",
      })
    end

    it "persists a 'join table' to faciliate many to many" do
      object_store[:users].save(hansel)

      expect(datastore).to have_persisted(:categories_to_posts, {
        category_id: "categories/1",
        post_id: "posts/1",
      })
    end

    context "when saving a second time" do
      context "when the first time is successful" do
        before do
          object_store[:users].save(hansel)
        end

        it "does not double write to the database" do
          expect {
            object_store[:users].save(hansel)
          }.not_to change { query_counter.write_count }
        end
      end

      context "when the first time fails" do
        before do
          attempt_unpersistable_save
        end

        let(:unpersistable) { Object.new }

        it "successfully saves all attributes the second time" do
          object_store[:users].save(hansel)

          expect(datastore).to have_persisted(
            :users,
            hash_including(
              id: hansel.id,
              email: hansel.email,
              first_name: hansel.first_name,
              last_name: hansel.last_name,
            )
          )
        end

        def attempt_unpersistable_save
          email = hansel.email
          hansel.email = unpersistable
          object_store[:users].save(hansel)
        rescue Terrestrial::UpsertError
          hansel.email = email
        end
      end
    end
  end
end
