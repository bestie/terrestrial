require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"
require "sequel_mapper/configurations/conventional_configuration"

RSpec.describe "Ordered associations" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  context "one to many association ordered by `created_at DESC`" do
    let(:posts) { user_mapper.first.posts }

    before do
      configs.fetch(:users).fetch(:associations).fetch(:posts).merge!(
        order: SequelMapper::QueryOrder.new(
          fields: [:created_at],
          direction: "DESC",
        )
      )
    end

    it "enumerates the objects in order specified in the config" do
      expect(posts.map(&:id)).to eq(
        posts.to_a.sort_by(&:created_at).reverse.map(&:id)
      )
    end
  end

  context "many to many associatin ordered by reverse alphabetical name" do
    before do
      configs.fetch(:posts).fetch(:associations).fetch(:categories).merge!(
        order: SequelMapper::QueryOrder.new(
          fields: [:name],
          direction: "DESC",
        )
      )
    end

    let(:categories) { user_mapper.first.posts.first.categories }

    it "enumerates the objects in order specified in the config" do
      expect(categories.map(&:id)).to eq(
        categories.to_a.sort_by(&:name).reverse.map(&:id)
      )
    end
  end
end
