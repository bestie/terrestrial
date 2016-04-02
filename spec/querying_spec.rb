require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "terrestrial"

RSpec.describe "Querying" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  subject(:mapper) { user_mapper }

  let(:user) {
    mapper.where(id: "users/1").first
  }

  let(:query_criteria) {
    {
      body: "I do it three times purrr day",
    }
  }

  let(:filtered_posts) {
    user.posts.where(query_criteria)
  }

  describe "arbitrary where query" do
    it "returns a filtered version of the association" do
      expect(filtered_posts.map(&:id)).to eq(["posts/2"])
    end

    it "delegates the query to the datastore, performs two additiona reads" do
      expect {
        filtered_posts.map(&:id)
      }.to change { query_counter.read_count }.by(2)
    end

    it "returns another collection" do
      expect(filtered_posts).not_to be(user.posts)
    end

    it "returns an immutable collection" do
      expect(filtered_posts.public_methods).not_to include(:push, :<<, :delete)
    end
  end
end
