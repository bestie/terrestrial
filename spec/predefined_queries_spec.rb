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

    it "maps the datastore query" do
      expect(users.query(:tricketts).map(&:first_name)).to match_array(%w(
        Jasper
        Hansel
      ))
    end
  end

  context "on a has many association" do
    before do
      mapper_config.setup_mapping(:posts) do |config|
        config.query(:about_laziness) do |dataset|
          dataset.where(body: /lazy/i)
        end
      end
    end

    let(:user) { users.first }

    it "maps the datastore query" do
      expect(user.posts.query(:about_laziness).map(&:id)).to eq(["post/2"])
    end
  end
end
