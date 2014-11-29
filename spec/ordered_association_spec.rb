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
      user.toots.to_a

      expect(user.toots.map(&:id).to_a)
        .to eq(user.toots.to_a.sort_by { |t| t.tooted_at }.map(&:id).reverse)
    end
  end
end
