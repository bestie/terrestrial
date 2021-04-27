require "spec_helper"

require "support/have_persisted_matcher"
require "support/object_store_setup"
require "support/seed_data_setup"

# Because some systems use triggers to generate/maintain timestamps at the
# database level they are used as an example for field that the database owns.
# This means the application layer should always read from and never write to
# that field.
RSpec.describe "Database owned fields", backend: "sequel" do
  include_context "object store setup"

  before(:all) do
    create_db_timestamp_tables
  end

  after(:all) do
    drop_db_timestamp_tables
  end

  let(:user_store) {
    object_store[:users]
  }

  let(:object_store) {
    Terrestrial.object_store(config: with_db_owned_fields_config)
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
      author: nil,
      subject: "Biscuits",
      body: "I like them",
      comments: [],
      categories: [],
      created_at: nil,
      updated_at: nil,
    )
  }

  let(:with_db_owned_fields_config) {
    Terrestrial.config(datastore)
      .setup_mapping(:users) { |users|
        users.has_many(:posts, foreign_key: :author_id)
      }
      .setup_mapping(:posts) { |posts|
        posts.relation_name(:timestamped_posts)
        posts.database_owned_field(:created_at)
        posts.database_owned_field(:updated_at)
      }
  }

  context "new objects" do
    it "adds the current time to the timestamp fields" do
      user_store.save(user_with_post)

      expect(datastore).to have_persisted(
        :timestamped_posts,
        hash_including(
          created_at: an_instance_of(Time),
        )
      )
    end

    it "updates the objects with the new timestamp values" do
      expect(post).to receive(:created_at=).with(an_instance_of(Time))

      user_store.save(user_with_post)
    end

    it "does not insert values for the database owned fields" do
      user_store.save(user_with_post)

      posts_insert = query_counter
        .inserts
        .select { |sql| sql.include?("timestamped_posts") }
        .fetch(0)

      expect(posts_insert).not_to include("created_at")
    end
  end

  context "updating existing objects" do
    before do
      user_store.save(user_with_post)
      post.body = "new body"
    end

    context "when the database owned value does not change" do
      it "regardless, updates the object with the returned value" do
        expect(post).to receive(:created_at=).with(an_instance_of(Time))

        user_store.save(user_with_post)
      end
    end

    context "when the value changes in the database (without worrying about how)" do
      before do
        datastore[:timestamped_posts]
          .where(id: post.id)
          .update("created_at" => party_time)
      end

      let(:party_time) { Time.parse("1999-01-01 00:00:00 UTC") }

      it "regardless, updates the object with the returned value" do
        expect(post).to receive(:created_at=).with(party_time)

        user_store.save(user_with_post)
      end
    end

    context "when the database owned value is changed in the object" do
      it "reverts the object value back to the database value (you may wish to prevent overwriting in your domain model)" do
        original_time = post.created_at
        party_time = Time.parse("1999-01-01 00:00:00 UTC")
        post.created_at = party_time

        expect(post).to receive(:created_at=).with(original_time)

        user_store.save(user_with_post)
      end

      it "does not insert values for the database owned fields" do
        user_store.save(user_with_post)

        posts_insert = query_counter
          .inserts
          .select { |sql| sql.include?("timestamped_posts") }
          .fetch(0)

        expect(posts_insert).not_to include("created_at")
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

  def drop_db_timestamp_tables
    Terrestrial::SequelTestSupport.drop_tables(schema.fetch(:tables).keys)
  end
end
