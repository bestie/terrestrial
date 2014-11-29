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

    it "sends the query directly to the datastore" do
      expect {
        user.posts
          .where(query_criteria)
          .map(&:id)
      }.to change { query_counter.read_count }.by(2)

      # TODO: this is a quick hack to assert that no superfluous records where
      #       loaded. Figure out a better way to check efficiency
      expect(mapper.send(:identity_map).values.map(&:id)).to match_array([
        "user/1",
        "post/2",
      ])
    end
  end
end
