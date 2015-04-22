require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"

RSpec.xdescribe "Ordered associations" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  context "of type `has_many`" do
    subject(:mapper) { user_mapper }

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
