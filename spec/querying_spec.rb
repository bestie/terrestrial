require "spec_helper"

require "sequel_mapper"
require "support/graph_fixture"

RSpec.describe "Querying" do
  include SequelMapper::GraphFixture

  subject(:graph) {
    SequelMapper::Graph.new(
      top_level_namespace: :users,
      datastore: datastore,
      relation_mappings: relation_mappings,
    )
  }

  let(:user) {
    graph.where(id: "user/1").first
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
      user.posts
        .where(query_criteria)
        .map(&:id)

      expect(datastore.read_count).to eq(2)

      # TODO: this is a quick hack to assert that no superfluous records where
      #       loaded. Figure out a better way to check efficiency
      expect(graph.send(:identity_map).values.map(&:id)).to match_array([
        "user/1",
        "post/2",
      ])
    end
  end
end
