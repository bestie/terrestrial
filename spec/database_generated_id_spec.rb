require "spec_helper"

require "support/have_persisted_matcher"
require "support/object_store_setup"
require "support/seed_data_setup"

RSpec.describe "Database generated IDs", backend: "sequel" do
  include_context "object store setup"

  before(:all) do
    create_serial_id_tables
  end

  after(:all) do
    drop_serial_id_tables
  end

  before(:each) do
    clean_serial_id_tables
  end

  let(:user_store) {
    object_store[:users]
  }

  let(:object_store) {
    Terrestrial.object_store(config: serial_id_config)
  }

  let(:user) {
    User.new(user_attrs)
  }

  let(:user_attrs) {
    {
      id: nil,
      first_name: "Hansel",
      last_name: "Trickett",
      email: "hansel@tricketts.org",
      posts: [],
    }
  }

  let(:serial_id_config) {
    Terrestrial.config(datastore)
      .setup_mapping(:users) { |users|
        users.use_database_id
        users.relation_name(:serial_id_users)
        users.has_many(:posts, foreign_key: :author_id)
      }
      .setup_mapping(:posts) { |posts|
        posts.use_database_id
        posts.relation_name(:serial_id_posts)
      }
  }

  it "persists the root node" do
    expected_sequence_id = get_next_sequence_value("serial_id_users")

    user_store.save(user)

    expect(datastore).to have_persisted(
      :serial_id_users,
      hash_including(
        id: expected_sequence_id,
        first_name: hansel.first_name,
        last_name: hansel.last_name,
        email: hansel.email,
      )
    )
  end

  it "updates the object with serial database ID" do
    expected_sequence_id = get_next_sequence_value("serial_id_users")

    user_store.save(user)

    expect(user.id).to eq(expected_sequence_id)
  end

  context "when persisting two associated objects" do
    before { user.posts.push(post) }

    let(:post) { Post.new(post_attrs) }

    let(:post_attrs) {
      {
        id: nil,
        subject: "Biscuits",
        body: "I like them",
        comments: [],
        categories: [],
        created_at: Time.parse("2015-09-05T15:00:00+01:00"),
        updated_at: Time.parse("2015-09-05T15:00:00+01:00"),
      }
    }

    it "persists both objects" do
      expected_user_sequence_id = get_next_sequence_value("serial_id_users")
      expected_post_sequence_id = get_next_sequence_value("serial_id_posts")

      user_store.save(user)

      expect(datastore).to have_persisted(
        :serial_id_users,
        hash_including(
          id: expected_user_sequence_id,
          first_name: hansel.first_name,
          last_name: hansel.last_name,
          email: hansel.email,
        )
      )

      expect(datastore).to have_persisted(
        :serial_id_posts,
        hash_including(
          id: expected_post_sequence_id,
          subject: "Biscuits",
          body: "I like them",
          created_at: Time.parse("2015-09-05T15:00:00+01:00"),
        )
      )
    end

    it "writes the foreign key" do
      user_store.save(user)

      expect(datastore[:serial_id_posts].first.fetch(:author_id)).to eq(user.id)
    end
  end

  context "after an initial successful save of the object graph" do
    before do
      user_store.save(user)
    end

    context "when saving again without modifications" do
      it "does not perform any more database writes" do
        expect {
          user_store.save(user)
        }.not_to change { query_counter.write_count }
      end

      it "does not produce any change records" do
        expect(user_store.changes(user)).to be_empty
      end
    end
  end

  context "when updating an existing record" do
    before do
      user_store.save(user)
    end

    it "performs an update" do
      new_email = "hansel+alternate@gmail.com"
      user.email = new_email

      user_store.save(user)

      expect(datastore).to have_persisted(
        :serial_id_users,
        hash_including(
          id: user.id,
          email: new_email,
        )
      )
    end
  end

  context "when the user id must be set by an unconventional method" do
    before do
      change_objects_id_setter_method(user)
    end

    let(:serial_id_config) {
      Terrestrial.config(datastore)
        .setup_mapping(:users) { |users|
          users.use_database_id { |object, new_id| object.unusual_id_setter(new_id) }
          users.relation_name(:serial_id_users)
        }
    }

    it "calls the user-defined config block which should update the ID" do
      next_id = get_next_sequence_value(:serial_id_users)
      expect(user).to receive(:unusual_id_setter).with(next_id)
      expect(user).not_to receive(:id=)

      user_store.save(user)
    end

    def change_objects_id_setter_method(user)
      def user.id=(*args)
        raise "This method should not be called"
      end

      def user.unusual_id_setter(value)
        @id = value
      end
    end
  end

  def serial_id_schema
    {
      :tables => {
        :serial_id_users => [
          {
            :name => :id,
            :type => Integer,
            :options => {
              :primary_key => true,
              :serial => true,
            },
          },
          {
            :name => :first_name,
            :type => String,
          },
          {
            :name => :last_name,
            :type => String,
          },
          {
            :name => :email,
            :type => String,
          },
        ],
        :serial_id_posts => [
          {
            :name => :id,
            :type => Integer,
            :options => {
              :primary_key => true,
              :serial => true,
            },
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
            :type => Integer,
          },
          {
            :name => :created_at,
            :type => DateTime,
          },
        ],
      },
      :foreign_keys => [
        [
          :posts,
          :author_id,
          :users,
          :id,
        ],
      ],
    }
  end

  def create_serial_id_tables
    Terrestrial::SequelTestSupport.create_tables(serial_id_schema.fetch(:tables))
  end

  def drop_serial_id_tables
    Terrestrial::SequelTestSupport.drop_tables(serial_id_schema.fetch(:tables).keys)
  end

  def clean_serial_id_tables
    Terrestrial::SequelTestSupport.clean_tables(serial_id_schema.fetch(:tables).keys)
  end

  def get_next_sequence_value(table_name)
    datastore["select currval(pg_get_serial_sequence('#{table_name}', 'id'))"]
      .to_a
      .fetch(0)
      .fetch(:currval) + 1
  rescue Sequel::DatabaseError => e
    if /PG::ObjectNotInPrerequisiteState/.match?(e.message)
      1
    else
      raise e
    end
  end
end
