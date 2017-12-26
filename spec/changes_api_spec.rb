require "spec_helper"

require "support/object_store_setup"
require "support/seed_data_setup"
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

        expect(user_store.changes(user)).to eq(
          [
            Terrestrial::UpsertedRecord.new(
              :users,
              [:id],
              {
                id: "users/1",
                email: modified_email,
              },
              0,
            )
          ]
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
              "DO UPDATE SET \"email\" = 'hasel+modified@gmail.com'",
          ]
        )
      end
    end
  end
end
