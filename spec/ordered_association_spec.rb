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

  subject(:user_mapper) {
    SequelMapper.mapper(
      config: mapper_config,
      name: :users,
      datastore: datastore,
    )
  }


  context "one to many association ordered by `created_at DESC`" do
    let(:posts) { user_mapper.first.posts }

    let(:mapper_config) {
      SequelMapper::Configurations::ConventionalConfiguration.new(datastore)
        .setup_mapping(:users) { |users|
          users.has_many(:posts, foreign_key: :author_id, order_fields: [:created_at], order_direction: "DESC")
        }
    }

    it "enumerates the objects in order specified in the config" do
      expect(posts.map(&:id)).to eq(
        posts.to_a.sort_by(&:created_at).reverse.map(&:id)
      )
    end
  end

  context "many to many associatin ordered by reverse alphabetical name" do
    let(:mapper_config) {
      SequelMapper::Configurations::ConventionalConfiguration.new(datastore)
        .setup_mapping(:users) { |users|
          users.has_many(:posts, foreign_key: :author_id)
        }
        .setup_mapping(:posts) { |posts|
          posts.has_many_through(:categories, order_fields: [:name], order_direction: "DESC")
        }
    }

    let(:categories) { user_mapper.first.posts.first.categories }

    it "enumerates the objects in order specified in the config" do
      expect(categories.map(&:id)).to eq(
        categories.to_a.sort_by(&:name).reverse.map(&:id)
      )
    end
  end
end
