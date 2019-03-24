require "spec_helper"

require "support/object_store_setup"
require "support/seed_data_setup"
require "support/have_persisted_matcher"
require "terrestrial"

RSpec.describe "Changes API", backend: "sequel" do
  include_context "object store setup"
  include_context "seed data setup"

  subject(:user_store) { object_store.fetch(:users) }

  let(:user) {
    user_store.where(id: "users/1").first
  }

  describe "#changes" do
    context "when there are no changes" do
      it "returns an empty change set" do
        expect(user_store.changes(user)).to be_empty
      end
    end

    context "when loading and modifying only the root node" do
      let(:modified_email) { "hasel+modified@gmail.com" }

      it "returns changes to only that node" do
        user.email = modified_email

        expect(user_store.changes(user).map(&:to_h)).to eq(
          [
            {
              id: "users/1",
              email: modified_email,
            }
          ]
        )
      end

      it "does not persist the changes" do
        user.email = modified_email

        user_store.changes(user)

        expect(datastore).not_to have_persisted(
          :users,
          hash_including(
            id: user.id,
            email: modified_email,
          )
        )
      end
    end
  end

  describe "#changes_sql" do
    context "when there are no changes" do
      it "returns an empty list" do
        expect(user_store.changes_sql(user)).to be_empty
      end
    end

    context "when loading and modifying only the root node" do
      let(:modified_email) { "hasel+modified@gmail.com" }

      it "returns the upsert statement for just that change" do
        user.email = modified_email

        expect(user_store.changes_sql(user)).to eq(
          [
            "INSERT INTO \"users\" (\"email\", \"id\") VALUES " \
              "('hasel+modified@gmail.com', 'users/1') ON CONFLICT (\"id\") " \
              "DO UPDATE SET \"email\" = 'hasel+modified@gmail.com' " \
              "RETURNING *",
          ]
        )
      end
    end
  end
end
