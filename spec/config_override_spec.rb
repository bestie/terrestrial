require "spec_helper"

require "sequel_mapper"
require "support/database_fixture"
require "sequel_mapper/struct_factory"

RSpec.describe "Configuration override" do
  include SequelMapper::DatabaseFixture

  subject(:mapper) { mapper_fixture }

  let(:user) {
    mapper.where(id: "user/1").first
  }

  before do
    SequelMapper::SequelTestSupport.drop_tables
  end

  context "override the root mapper factory" do
    context "with a Struct class" do
      before do
        mapper_config.setup_mapping(:users) do |config|
          config.factory(user_subclass)
        end
      end

      let(:user_subclass) { Class.new(User) }

      it "uses the class from the override" do
        expect(user.class).to be(user_subclass)
      end
    end
  end

  context "override an association" do
    context "with a callable factory" do
      before do
        mapper_config.setup_mapping(:posts) do |config|
          config.factory(override_post_factory)
        end
      end

      let(:post_subclass) { Class.new(Post) }

      let(:override_post_factory) {
        SequelMapper::StructFactory.new(post_subclass)
      }

      let(:posts) {
        user.posts
      }

      it "uses the specified factory" do
        expect(posts.first.class).to be(post_subclass)
      end
    end
  end

  context "override table names" do
    let(:datastore) { db_connection }

    let(:users_table_name) {
      :users_is_called_this_weird_thing_perhaps_for_legacy_reasons
    }

    let(:strange_data) {
      {
        users_table_name => fixture_tables_hash.fetch(:users),
      }
    }

    before do
      write_fixture_data(datastore, strange_data)
    end

    let(:mapper_config) {
      SequelMapper::Configurations::ConventionalConfiguration
        .new(datastore)
        .setup_mapping(:users) do |config|
          config.relation_name users_table_name
        end
    }

    context "for just the top level mapping" do
      it "maps data from the specified relation" do
        expect(
          mapper.map(&:id)
        ).to eq(["user/1", "user/2", "user/3"])
      end
    end

    context "for associated collections" do
      let(:strange_table_name_map) {
        {
          :users => :users_table_that_has_silly_name_perhaps_for_legacy_reasons,
          :posts => :thank_you_past_self_for_this_excellent_name,
          :categories => :these_are_the_categories_for_real,
          :categories_to_posts => :this_one_is_just_full_of_bees,
        }
      }

      let(:strange_data) {
        Hash[
          strange_table_name_map.map { |good_name, bad_name|
            [bad_name, fixture_tables_hash.fetch(good_name)]
          }
        ]
      }

      before do
        write_fixture_data(datastore, strange_data)

        mapper_config
          .setup_mapping(:users) do |config|
            config.relation_name strange_table_name_map.fetch(:users)
            config.has_many(:posts, foreign_key: :author_id)
          end
          .setup_mapping(:posts) do |config|
            config.relation_name strange_table_name_map.fetch(:posts)
            config.belongs_to(:author, mapping_name: :users)
            config.has_many_through(:categories, join_table_name: strange_table_name_map.fetch(:categories_to_posts))
          end
          .setup_mapping(:categories) do |config|
            config.relation_name strange_table_name_map.fetch(:categories)
            config.has_many_through(:posts, join_table_name: strange_table_name_map.fetch(:categories_to_posts))
          end
      end

      it "maps data from the specified relation into a has many collection" do
        expect(
          user.posts.map(&:id)
        ).to eq(["post/1", "post/2"])
      end

      it "maps data from the specified relation into a belongs to field" do
        expect(
          user.posts.first.author
        ).to eq(user)
      end
    end
  end
end
