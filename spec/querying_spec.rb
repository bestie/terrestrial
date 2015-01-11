require "spec_helper"

require "sequel_mapper"
require "support/database_fixture"

RSpec.describe "Querying" do
  include SequelMapper::DatabaseFixture

  subject(:mapper) { mapper_fixture }

  let(:user) {
    mapper.where(id: "user/1").first
  }

  let(:query_criteria) {
    {
      body: "Lazy load all the things!",
    }
  }

  let(:filtered_posts) {
    user.posts.where(query_criteria)
  }

  describe "arbitrary where query" do
    it "returns a filtered version of the association" do
      expect(filtered_posts.map(&:id)).to eq(["post/2"])
    end

    it "delegates the query to the datastore, performs two additiona reads" do
      expect {
        filtered_posts.map(&:id)
      }.to change { query_counter.read_count }.by(2)
    end

    it "returns another collection" do
      expect(filtered_posts).not_to be(user.posts)
    end
  end
end
