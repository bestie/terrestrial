require "spec_helper"

require "support/have_persisted_matcher"
require "support/object_store_setup"
require "support/seed_data_setup"

RSpec.describe "Database default fields", backend: "sequel" do
  include_context "object store setup"

  before(:all) do
    create_db_timestamp_tables
  end

  after(:all) do
    drop_db_timestamp_tables
  end

  before do
    clean_db_timestamp_tables
  end

  let(:user_store) {
    object_store[:users]
  }

  let(:object_store) {
    Terrestrial.object_store(config: with_db_default_fields_config)
  }

  let(:user_with_post) {
    User.new(
      id: "users/1",
      first_name: "Hansel",
      last_name: "Trickett",
      email: "hansel@tricketts.org",
      posts: [post],
    )
  }

  let(:post) {
    Post.new(
      id: "posts/1",
      subject: "Biscuits",
      body: "I like them",
      comments: [],
      categories: [],
      created_at: nil,
      updated_at: nil,
    )
  }

  let(:party_time) { Time.parse("1999-01-01 00:00:00 UTC") }

  let(:with_db_default_fields_config) {
    Terrestrial.config(datastore)
      .setup_mapping(:users) { |users|
        users.has_many(:posts, foreign_key: :author_id)
      }
      .setup_mapping(:posts) { |posts|
        posts.relation_name(:timestamped_posts)
        posts.database_default_field(:created_at)
        posts.database_default_field(:updated_at)
      }
  }

  context "new objects" do
    context "when the object's value is nil" do
      before do
        post.created_at = nil
      end

      it "updates the object with the new default value" do
        expect(post).to receive(:created_at=).with(an_instance_of(Time))

        user_store.save(user_with_post)
      end
    end

    context "when the object's value has been set to something" do
      before do
        post.created_at = party_time
      end

      it "does not set a value on the object" do
        expect(post).not_to receive(:created_at=).with(party_time)

        user_store.save(user_with_post)
      end

      it "persists the user-defined value" do
        user_store.save(user_with_post)

        expect(datastore).to have_persisted(
          :timestamped_posts,
          hash_including(
            id: post.id,
            created_at: party_time,
          )
        )
      end
    end
  end

  context "updating existing objects" do
    before do
      user_store.save(user_with_post)
      post.body = "new body"
    end

    it "regardless, updates the object with the returned value" do
      expect(post).to receive(:created_at=).with(an_instance_of(Time))

      user_store.save(user_with_post)
    end

    context "when the value changes in the database (e.g. a trigger)" do
      before do
        datastore[:timestamped_posts]
          .where(id: post.id)
          .update("created_at" => party_time)
      end

      it "regardless, updates the object with the returned value" do
        expect(post).to receive(:created_at=).with(party_time)

        user_store.save(user_with_post)
      end
    end

    context "when the object's value is modified by the application"  do
      it "does not modify the object" do
        original_time = post.created_at
        post.created_at = party_time

        expect(post).not_to receive(:created_at=)

        user_store.save(user_with_post)
        expect(post.created_at).to eq(party_time)
      end

      it "persists the object's new value" do
        post.created_at = party_time

        user_store.save(user_with_post)

        expect(datastore).to have_persisted(
          :timestamped_posts,
          hash_including(
            id: post.id,
            created_at: party_time,
          )
        )
      end
    end
  end

  def schema
    {
      :tables => {
        :timestamped_posts => [
          {
            :name => :id,
            :type => String,
            :options => {
              :primary_key => true,
            }
          },
          {
            :name => :subject,
            :type => String,
          },
          {
            :name => :body,
            :type => String,
          },
          {
            :name => :author_id,
            :type => String,
          },
          {
            :name => :created_at,
            :type => DateTime,
            :options => {
              :default => Sequel::CURRENT_TIMESTAMP,
              :null => false,
            },
          },
          {
            :name => :updated_at,
            :type => DateTime,
            :options => {
              :default => Sequel::CURRENT_TIMESTAMP,
              :null => false,
            },
          },
        ],
      },
    }
  end

  def create_db_timestamp_tables
    Terrestrial::SequelTestSupport.create_tables(schema.fetch(:tables))
  end

  def clean_db_timestamp_tables
    Terrestrial::SequelTestSupport.clean_tables(schema.fetch(:tables).keys)
  end

  def drop_db_timestamp_tables
    Terrestrial::SequelTestSupport.drop_tables(schema.fetch(:tables).keys)
  end
end
