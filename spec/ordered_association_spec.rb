require "spec_helper"

require "sequel_mapper"
require "support/database_fixture"

RSpec.describe "Ordered associations" do
  include SequelMapper::DatabaseFixture

  context "of type `has_many`" do
    subject(:mapper) { mapper_fixture }

    let(:user) {
      mapper.where(id: "user/1").first
    }

    it "enumerates the objects in order specified in the config" do
      time_sorted_ids = user.toots.sort_by { |t| t.tooted_at }.map(&:id).reverse

      expect(user.toots.map(&:id).to_a)
        .to eq(time_sorted_ids)
    end
  end
end
