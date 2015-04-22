require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"

RSpec.describe "Predefined queries" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  subject(:users) { user_mapper }

  context "on the top level maper" do
    context "query is defined with a block" do
      before do
        mapper_config.setup_mapping(:users) do |config|
          config.query(:tricketts) do |dataset|
            dataset
              .where(last_name: "Trickett")
              .order(:first_name)
          end
        end
      end

      it "maps the result of the query" do
        expect(users.query(:tricketts).map(&:first_name)).to eq([
          "Hansel",
          "Jasper",
        ])
      end
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
