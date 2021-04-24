require "spec_helper"

require "support/have_persisted_matcher"
require "support/object_store_setup"
require "support/seed_data_setup"

RSpec.describe "Automatic timestamps", backend: "sequel" do
  include_context "object store setup"

  before(:all) do
    create_db_timestamp_tables
  end

  after(:all) do
    drop_db_timestamp_tables
  end

  before(:each) do
    clean_db_timestamp_tables
  end

  let(:user_store) {
    object_store[:users]
  }

  let(:object_store) {
    Terrestrial.object_store(config: with_auto_timestamps_config)
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
      updated_at: nil,
      created_at: nil,
    )
  }

  let(:clock) {
    StaticClock.new(Time.parse("2020-04-20T17:00:00 UTC"))
  }

  let(:with_auto_timestamps_config) {
    Terrestrial.config(datastore, clock: clock)
      .setup_mapping(:users) { |users|
        users.has_many(:posts, foreign_key: :author_id)
      }
      .setup_mapping(:posts) { |posts|
        posts.relation_name(:timestamped_posts)
        posts.created_at_timestamp
        posts.updated_at_timestamp
      }
  }

  context "new objects" do
    it "adds the current time to the timestamp fields" do
      expected_timestamp = clock.now.utc

      user_store.save(user_with_post)

      expect(datastore).to have_persisted(
        :timestamped_posts,
        hash_including(
          created_at: expected_timestamp,
          updated_at: expected_timestamp,
        )
      )
    end

    it "updates the objects with the new timestamp values" do
      expect(post).to receive(:created_at=).with(clock.now)
      expect(post).to receive(:updated_at=).with(clock.now)

      user_store.save(user_with_post)
    end
  end

  context "after an initial successful save of the object graph" do
    before do
      user_store.save(user_with_post)
    end

    context "if the clock has not yet advanced" do
      context "when saving again without modifications" do
        it "does not perform any more database writes" do
          expect {
            user_store.save(user_with_post)
          }.not_to change { query_counter.write_count }
        end

        it "does not produce any change records" do
          expect(user_store.changes(user_with_post)).to be_empty
        end
      end
    end

    context "when saving modifications and the clock has advanced" do
      before do
        @created_at_time = clock.now
        clock.tick
      end
      let(:created_at_time) { @created_at_time }

      it "persists the updated_at field at the current time" do
        current_time = clock.now
        post.body = post.body + " edited"

        user_store.save(user_with_post)

        expect(datastore).to have_persisted(
          :timestamped_posts,
          hash_including(
            id: post.id,
            body: post.body,
            updated_at: current_time,
          )
        )
      end

      it "updates the object's updated_at field to the current time" do
        current_time = clock.now
        post.body = post.body + " edited"

        expect(post).to receive(:updated_at=).with(current_time)

        user_store.save(user_with_post)
      end

      it "does not change the created_at time" do
        post.body = post.body + " edited"

        user_store.save(user_with_post)

        expect(datastore).to have_persisted(
          :timestamped_posts,
          hash_including(
            id: post.id,
            created_at: created_at_time,
          )
        )
      end
    end
  end

  context "user modifies a the created_at field" do
    it "persists the user's value" do
      party_time = Time.parse("1999-01-01t00:00:00 utc")
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

  context "with user-defined timestamp callbacks" do
    before do
      post = user_with_post.posts.first
      change_objects_timestamp_setter_methods(post)
    end

    let(:with_auto_timestamps_config) {
      Terrestrial.config(datastore, clock: clock)
        .setup_mapping(:users) { |users|
          users.has_many(:posts, foreign_key: :author_id)
        }
        .setup_mapping(:posts) { |posts|
          posts.relation_name(:timestamped_posts)
          posts.created_at_timestamp { |object, timestamp|
            object.unconventional_created_at = timestamp
          }
          posts.updated_at_timestamp { |object, timestamp|
            object.unconventional_updated_at = timestamp
          }
        }
    }

    it "sets the timestamps via the callbacks" do
      post = user_with_post.posts.first

      user_store.save(user_with_post)

      expect(post.created_at).to eq(clock.now)
      expect(post.updated_at).to eq(clock.now)
    end

    xcontext "if there's an error in the callback" do
      before do
        post = user_with_post.posts.first

        def post.unconventional_updated_at=(time)
          raise "Original error message"
        end
      end

      it "is caught, wrapped and re-raised" do
        expect {
          user_store.save(user_with_post)
        }.to raise_error(
          "Error running user-defined setter function defined in Terrestrial mapping lib/spec/automatic_timestamps_spec.rb:183.\n" +
          "Got Error: Original error message"
        )
      end

      it "raises an error which has a backtrace pointing to where the callback is invoked" do
        begin
          user_store.save(user_with_post)
        rescue => e
        ensure
          unless e
            raise "Failed to intentionally raise error in code under test"
          end

          puts filtered_backtrace = filter_library_code_from_backtrace(e.backtrace)

          actual_setter_location = /#{__FILE__}:[0-9]+:in .unconventional_created_at=/

          expected_files_and_methods = [
            actual_setter_location,
            /time_stamp_observer\.rb:[0-9]+:in .post_save/,
            /relation_mapping\.rb:[0-9]+:in .post_save/,
            /upsert_record\.rb:[0-9]+:in .on_upsert/,
            /upsert_record\.rb:[0-9]+:in .if_upsert/,
          ]

          aggregate_failures do
            expected_files_and_methods.each do |pattern|
              # TODO: Seems like this should be possible with an RSpec machter for a better failure message
              expect(filtered_backtrace.any? { |l| pattern.match(l) }).to be true
            end
          end
        end
      end

      def filter_library_code_from_backtrace(backtrace)
        backtrace
          .reject { |l| l.include?("lib/rspec") }
          .reject { |l| l.include?("lib/bundler") }
          .reject { |l| l.include?("lib/sequel") }
      end
    end

    def change_objects_timestamp_setter_methods(post)
      def post.created_at=(_)
        raise "Should not be called"
      end
      def post.updated_at=(_)
        raise "Should not be called"
      end
      def post.unconventional_created_at=(time)
        @created_at = time
      end
      def post.unconventional_updated_at=(time)
        @updated_at = time
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
          },
          {
            :name => :updated_at,
            :type => DateTime,
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

  def clean_db_timestamp_tables
    Terrestrial::SequelTestSupport.clean_tables(schema.fetch(:tables).keys)
  end

  class StaticClock
    def initialize(time)
      @time = time
    end

    def now
      @time
    end

    def tick
      @time += 1
    end
  end
end
