require "spec_helper"

require "sequel_mapper"
require "support/database_fixture"

RSpec.describe "Predefined queries" do
  include SequelMapper::DatabaseFixture

  subject(:users) { mapper_fixture }

  # let(:user) {
  #   mapper.where(id: "user/1").first
  # }

  context "on the top level" do
    before do
      mapper_config.setup_mapping(:users) do |config|
        config.query(:tricketts) do |dataset|
          dataset.where(last_name: "Trickett")
        end
      end
    end

    it "maps a datastore optimized query" do
      expect(users.query(:tricketts).map(&:first_name)).to match_array(%w(
        Jasper
        Hansel
      ))
    end
  end
end
