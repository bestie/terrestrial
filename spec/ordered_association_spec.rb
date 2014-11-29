require "spec_helper"

require "sequel_mapper"
require "support/graph_fixture"

RSpec.describe "Ordered associations" do
  include SequelMapper::GraphFixture

  context "of type `has_many`" do
    subject(:graph) { mapper_fixture }

    let(:user) {
      graph.where(id: "user/1").first
    }

    it "enumerates the objects in order specified in the config" do
      user.toots.to_a

      expect(user.toots.map(&:id).to_a)
        .to eq(user.toots.to_a.sort_by { |t| t.tooted_at }.map(&:id).reverse)
    end
  end
end
