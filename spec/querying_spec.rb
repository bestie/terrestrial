require "spec_helper"

require "support/object_store_setup"
require "support/seed_data_setup"
require "terrestrial"

RSpec.describe "Querying" do
  include_context "object store setup"
  include_context "seed data setup"

  subject(:user_store) { object_store[:users] }
  let(:post_store) { object_store[:posts] }

  describe "querying the object store (users)" do
    it "queries by id" do
      expect(user_store.where(id: "users/1")).to contain_obj(User, id: "users/1")
    end

    it "queries by string field" do
      expect(user_store.where(first_name: "Hansel")).to contain_obj(User, id: "users/1")
    end

    it "queries by multiple fields (AND)" do
      results = user_store
        .where(last_name: "Trickett")
        .where(first_name: "Jasper")
        .to_a

      expect(results.length).to eq(1)
      expect(results.first.id).to eq("users/2")
    end

    it "returns multiple matching results" do
      results = user_store.where(last_name: "Trickett").to_a

      expect(results.length).to eq(2)
      expect(results.map(&:id)).to contain_exactly("users/1", "users/2")
    end

    it "returns empty when nothing matches" do
      results = user_store.where(first_name: "Nonexistent").to_a

      expect(results).to be_empty
    end

    it "queries with an array (IN)" do
      results = user_store.where(id: ["users/1", "users/3"]).to_a

      expect(results.map(&:id)).to contain_exactly("users/1", "users/3")
    end

    it "queries with a regex" do
      results = user_store.where(email: /tricketts/).to_a

      expect(results.length).to eq(2)
      expect(results.map(&:last_name)).to all(eq("Trickett"))
    end

    it "chains where clauses" do
      results = user_store
        .where(last_name: "Trickett")
        .where(first_name: "Hansel")
        .to_a

      expect(results.length).to eq(1)
      expect(results.first.id).to eq("users/1")
    end
  end

  describe "querying posts (time, boolean, nil)" do
    it "queries by exact time" do
      results = post_store.where(created_at: Time.parse("2015-09-02 15:00:00 UTC")).to_a

      expect(results.length).to eq(1)
      expect(results.first.subject).to eq("Biscuits")
    end

    it "queries by time range (BETWEEN)" do
      from = Time.parse("2015-09-03 00:00:00 UTC")
      to   = Time.parse("2015-09-06 00:00:00 UTC")

      results = post_store.where(created_at: (from..to)).to_a

      expect(results.map(&:subject)).to contain_exactly("Sleeping", "Catching frongs")
    end

    it "queries by endless range (>=)" do
      from = Time.parse("2015-09-05 00:00:00 UTC")

      results = post_store.where(created_at: (from..)).to_a

      expect(results.map(&:subject)).to contain_exactly("Catching frongs", "Chewing up boxes")
    end

    it "queries by beginless range (<=)" do
      to = Time.parse("2015-09-03 00:00:00 UTC")

      results = post_store.where(created_at: (..to)).to_a

      expect(results.map(&:subject)).to contain_exactly("Biscuits")
    end

    it "queries by boolean true" do
      results = post_store.where(published: true).to_a

      expect(results.map(&:subject)).to contain_exactly("Biscuits", "Sleeping")
    end

    it "queries by boolean false" do
      results = post_store.where(published: false).to_a

      expect(results.map(&:subject)).to contain_exactly("Catching frongs", "Chewing up boxes")
    end

    it "queries by nil (IS NULL)" do
      results = post_store.where(updated_at: nil).to_a

      expect(results.length).to eq(4)
    end

    context "querying with an unknown type", backend: "activerecord" do
      it "prints a warning, throws an error" do
        unknown = Object.new

        error = nil
        expect {
          begin
            post_store.where(subject: unknown).to_a
          rescue => error
          end
        }.to output(
          /Warning: Terrestrial doesn't know how to convert object to constraint for posts\.subject/
        ).to_stderr

        expect(error).to be_a(Terrestrial::Adapters::ActiveRecordPostgresAdapter::Dataset::QueryBuildError)
        expect(error.cause).to be_a(TypeError)
      end
    end
  end

  describe "association#where - filtering associations of the root (user) object" do
    let(:user) { user_store.where(id: "users/1").first }

    it "returns a subset of the associated objects" do
      posts = user.posts.where(subject: "Biscuits").to_a

      expect(posts.length).to eq(1)
      expect(posts.first.subject).to eq("Biscuits")
    end

    it "returns a different collection object" do
      all_posts = user.posts
      filtered = user.posts.where(subject: "Biscuits")

      expect(filtered).not_to equal(all_posts)
    end

    it "does not modify the original collection" do
      all_posts = user.posts
      original_count = all_posts.to_a.length

      user.posts.where(subject: "Biscuits").to_a

      expect(all_posts.to_a.length).to eq(original_count)
    end

    it "supports querying by boolean" do
      published = user.posts.where(published: true).to_a

      expect(published.map(&:subject)).to contain_exactly("Biscuits", "Sleeping")
    end

    it "supports querying by time range" do
      from = Time.parse("2015-09-03 00:00:00 UTC")
      to   = Time.parse("2015-09-04 00:00:00 UTC")

      posts = user.posts.where(created_at: (from..to)).to_a

      expect(posts.length).to eq(1)
      expect(posts.first.subject).to eq("Sleeping")
    end
  end

  def contain_obj(type, **attrs)
    satisfy("contain a #{type} with #{attrs}") { |collection|
      collection.any? { |obj|
        obj.is_a?(type) && attrs.all? { |k, v| obj.send(k) == v }
      }
    }
  end
end
