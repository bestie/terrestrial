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

  describe "arbitrary where query" do
    it "returns a filtered version of the association" do
      expect(
        user.posts
          .where(query_criteria)
          .map(&:id)
      ).to eq(["post/2"])
    end

    it "delegates the query to the datastore, performs two additiona reads" do
      expect {
        user.posts
          .where(query_criteria)
          .map(&:id)
      }.to change { query_counter.read_count }.by(2)
    end
  end
end
