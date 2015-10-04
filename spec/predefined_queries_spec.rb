require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"
require "sequel_mapper/configurations/conventional_configuration"

RSpec.describe "Predefined subset queries" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  subject(:users) { user_mapper }

  subject(:user_mapper) {
    SequelMapper.mapper(
      config: mapper_config,
      name: :users,
      datastore: datastore,
    )
  }

  let(:mapper_config) {
    SequelMapper::Configurations::ConventionalConfiguration.new(datastore)
      .setup_mapping(:users) { |users|
        users.has_many :posts, foreign_key: :author_id
      }
  }

  context "on the top level mapper" do
    context "subset is defined with a block" do
      before do
        mapper_config.setup_mapping(:users) do |config|
          config.subset(:tricketts) do |dataset|
            dataset
              .where(last_name: "Trickett")
              .order(:first_name)
          end
        end
      end

      it "maps the result of the subset" do
        expect(users.subset(:tricketts).map(&:first_name)).to eq([
          "Hansel",
          "Jasper",
        ])
      end
    end
  end

  context "on a has many association" do
    before do
      mapper_config.setup_mapping(:posts) do |config|
        config.subset(:body_contains) do |dataset, search_string|
          dataset.where("body like '%#{search_string}%'")
        end
      end
    end

    let(:user) { users.first }

    it "maps the datastore subset" do
      expect(user.posts.subset(:body_contains, "purrr").map(&:id))
        .to eq(["posts/2"])
    end

    it "returns an immutable collection" do
      expect(user.posts.subset(:body_contains, "purrr").public_methods)
        .not_to include(:push, :<<, :delete)
    end
  end
end
