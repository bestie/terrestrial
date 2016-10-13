require "spec_helper"

require "support/object_store_setup"
require "support/seed_data_setup"
require "terrestrial"
require "terrestrial/configurations/conventional_configuration"

RSpec.describe "Predefined subset queries" do
  include_context "object store setup"
  include_context "seed data setup"

  subject(:users) { object_store[:users] }

  context "on the top level mapper" do
    context "subset is defined with a block" do
      before do
        configs.fetch(:users).merge!(
          subsets: {
            tricketts: ->(dataset) {
              dataset
                .where(last_name: "Trickett")
                .order(:first_name)
            },
          },
        )
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
      configs.fetch(:posts).merge!(
        subsets: {
          body_contains: ->(dataset, search_string) {
            dataset.where(body: /#{search_string}/)
          },
        },
      )
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
