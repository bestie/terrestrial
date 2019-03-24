require "spec_helper"
require "ostruct"

require "support/object_store_setup"
require "support/seed_data_setup"
require "terrestrial"

require "terrestrial/configurations/conventional_configuration"

RSpec.describe "Configuration override" do
  include_context "object store setup"
  include_context "seed data setup"

  let(:object_store) {
    Terrestrial.object_store(config: override_config)
  }

  let(:override_config) {
    Terrestrial::config(datastore)
      .setup_mapping(:users) { |users|
        users.has_many :posts, foreign_key: :author_id
        users.fields([:id, :first_name, :last_name, :email])
      }
      .setup_mapping(:posts)
  }

  context "override the root mapper factory" do
    context "with a Struct class" do
      before do
        override_config.setup_mapping(:users) do |config|
          config.class(user_struct)
        end
      end

      let(:user_struct) { Struct.new(*User.members) }

      it "uses the class from the override" do
        user = object_store[:users].where(id: "users/1").first

        expect(user.class).to be(user_struct)
      end
    end
  end

  context "override an association" do
    context "with a callable factory" do
      before do
        override_config.setup_mapping(:posts) do |config|
          config.factory(override_post_factory)
          config.fields([:id, :subject, :body, :created_at])
        end
      end

      let(:post_class) { Class.new(OpenStruct) }

      let(:override_post_factory) {
        post_class.method(:new)
      }

      it "uses the specified factory" do
        user = object_store[:users].where(id: "users/1").first
        posts = user.posts

        expect(posts.first.class).to be(post_class)
      end
    end
  end

  context "override table names" do
    context "for just the top level mapping" do
      before do
        datastore.rename_table(:users, unconventional_table_name)
      end

      after do
        datastore.rename_table(unconventional_table_name, :users)
      end

      let(:override_config) {
        Terrestrial.config(datastore)
          .setup_mapping(:users) do |config|
            config.relation_name unconventional_table_name
            config.class(OpenStruct)
          end
      }

      let(:unconventional_table_name) {
        :users_is_called_this_weird_thing_perhaps_for_legacy_reasons
      }

      it "maps data from the specified relation" do
        expect(
          object_store[:users].map(&:id)
        ).to eq(["users/1", "users/2", "users/3"])
      end
    end

    context "for associated collections" do
      before do
        rename_all_the_tables
        setup_the_strange_table_name_mappings
      end

      after do
        undo_rename_all_the_tables
      end

      def rename_all_the_tables
        strange_table_name_map.each do |name, new_name|
          datastore.rename_table(name, new_name)
        end
      end

      def undo_rename_all_the_tables
        strange_table_name_map.each do |original_name, strange_name|
          datastore.rename_table(strange_name, original_name)
        end
      end

      def setup_the_strange_table_name_mappings
        override_config
          .setup_mapping(:users) do |config|
            config.class(OpenStruct)
            config.relation_name strange_table_name_map.fetch(:users)
            config.has_many(:posts, foreign_key: :author_id)
          end
          .setup_mapping(:posts) do |config|
            config.class(OpenStruct)
            config.relation_name strange_table_name_map.fetch(:posts)
            config.belongs_to(:author, mapping_name: :users)
            config.has_many_through(:categories, through_table_name: strange_table_name_map.fetch(:categories_to_posts))
          end
          .setup_mapping(:categories) do |config|
            config.class(OpenStruct)
            config.relation_name strange_table_name_map.fetch(:categories)
            config.has_many_through(:posts, through_table_name: strange_table_name_map.fetch(:categories_to_posts))
          end
      end

      let(:strange_table_name_map) {
        {
          :users => :users_table_that_has_silly_name_perhaps_for_legacy_reasons,
          :posts => :thank_you_past_self_for_this_excellent_name,
          :categories => :these_are_the_categories_for_real,
          :categories_to_posts => :this_one_is_just_full_of_bees,
        }
      }

      it "maps data from the specified relation into a has many collection" do
        user = object_store[:users].where(id: "users/1").first

        expect(
          user.posts.map(&:id)
        ).to eq(["posts/1", "posts/2"])
      end

      it "maps data from the specified relation into a has many through collection" do
        user = object_store[:users].where(id: "users/1").first

        expect(
          user.posts.flat_map(&:categories).map(&:id).uniq
        ).to eq(["categories/1", "categories/2"])
      end

      it "maps data from the specified relation into a `belongs_to` field" do
        user = object_store[:users].where(id: "users/1").first

        expect(
          user.posts.first.author.__getobj__.object_id
        ).to eq(user.object_id)
      end
    end
  end

  context "multiple mappings for single table" do
    TypeOneUser = Class.new(OpenStruct)
    TypeTwoUser = Class.new(OpenStruct)

    let(:override_config) {
      Terrestrial.config(datastore)
        .setup_mapping(:t1_users) { |c|
          c.class(TypeOneUser)
          c.table_name(:users)
        }
        .setup_mapping(:t2_users) { |c|
          c.class(TypeTwoUser)
          c.table_name(:users)
        }
    }

    it "provides access to the same data via the different configs" do
      expect(object_store[:t1_users].first.id).to eq("users/1")
      expect(object_store[:t1_users].first).to be_a(TypeOneUser)
      expect(object_store[:t2_users].first.id).to eq("users/1")
      expect(object_store[:t2_users].first).to be_a(TypeTwoUser)
    end
  end
end
