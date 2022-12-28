require "spec_helper"
require "support/unique_index_only_schema"

require "terrestrial/adapters/active_record_postgres_adapter"
require "terrestrial/upsert_record"

RSpec.describe Terrestrial::Adapters::ActiveRecordPostgresAdapter, backend: "activerecord" do
  let(:db_connection) { Terrestrial::ActiveRecordTestSupport.db_connection }
  let(:adapter) { Terrestrial::Adapters::ActiveRecordPostgresAdapter.new(db_connection) }

  describe "#execute" do
    context "simple select" do
      it "returns a the result" do
        raw_insert

        query = "SELECT * FROM users"
        result = adapter.execute(query)
        expect(result.to_a).to eq([attrs])
      end
    end
  end

  describe "#tables" do
    it "returns all table names as symbols" do
      expect(adapter.tables).to match_array(
        [:users, :posts, :categories, :comments, :categories_to_posts]
      )
    end
  end

  describe "#primary_key" do
    context "when the table has a regular primary key" do
      let(:table_name) { :users }
      it "returns the primary key field(s) for a table as an array of symbols" do
        expect(adapter.primary_key(table_name)).to eq([:id])
      end
    end

    context "when the table has no primary key" do
      let(:table_name) { :categories_to_posts }

      it "returns an empty array" do
        expect(adapter.primary_key(table_name)).to eq([])
      end
    end
  end

  describe "#relation_fields" do
    it "returns all available fields for a table" do
      expect(adapter.relation_fields(:users)).to eq(
        [:id, :first_name, :last_name, :email]
      )
    end
  end

  describe "persistence" do
    def raw_insert
      quoted_attrs = attrs.values.map { |s| "'#{s}'" }.join(",")
      db_connection.execute("INSERT INTO users (#{attrs.keys.join(",")}) VALUES (#{quoted_attrs})")
    end

    def raw_select
      db_connection.execute("SELECT * FROM users").to_a
    end

    describe "#delete" do
      it "deletes the record" do
        raw_insert

        adapter.delete(record)

        expect(raw_select).to be_empty
      end
    end

    xdescribe "#upsert_sql" do
      it "generates postgres compatible SQL using ActiveRecord's database adatper" do
        attrs = { id: "posts/1", name: "a post", created_at: Time.now }
      record = double(
        :record,
        identity_fields: [:id],
        identity: "post/1",
        namespace: :posts,
        to_h: attrs,
        insertable: attrs,
      )
# dw|| INSERT INTO posts (id,name,created_at) VALUES ('posts/1','a post','2022-09-11 10:26:10.260550') ON CONFLICT (id) DO UPDATE SET id=excluded.id,name=excluded.name,created_at=excluded.created_at RETURNING id
      puts adapter.upsert_sql(record)
        expect(adapter.upsert_sql(record)).to eq(
          "INSERT INTO users (id,first_name,last_name,email) " \
          "VALUES ('users/1','boop','snoot','bestie@gmail.com') "\
          "ON CONFLICT (id) DO UPDATE SET " \
          "id=excluded.id,first_name=excluded.first_name,last_name=excluded.last_name,email=excluded.email "\
          "RETURNING id"
        )
      end
    end

    describe "#upsert" do
      it "inserts a new record" do
        adapter.upsert(record)

        expect(raw_select.to_a).to eq([attrs_with_string_keys])
      end

      it "returns nil" do
        expect(adapter.upsert(record)).to be_nil
      end

      it "triggers the mapping's post_save callback via the record's on_upsert callback" do
        expect(mapping).to receive(:post_save)

        adapter.upsert(record)
      end

      context "when the record already exists" do
        before do
        end

        let(:new_name) { "New name!" }

        it "updates an existing record" do
          attrs.merge!(:first_name => new_name)
          update_result = adapter.upsert(record)

          select_result = raw_select.to_a
          expect(select_result.first).to match(hash_including("id" => "users/1", "first_name" => new_name))
        end
      end
    end
  end

  let(:attrs) { { id: "users/1", first_name: "boop", last_name: "snoot", email: "bestie@gmail.com" } }
  let(:attrs_with_string_keys) { attrs.transform_keys(&:to_s) }

  let(:record) {
    Terrestrial::UpsertRecord.new(
      mapping,
      double(:object),
      attrs,
      0,
    )
  }

  let(:mapping) {
    double(
      :mapping,
      namespace: :users,
      primary_key: [],
      database_owned_fields: [],
      database_default_fields: [],
      post_save: nil,
    )
  }

  def raw_insert
    quoted_attrs = attrs.values.map { |s| "'#{s}'" }.join(",")
    db_connection.execute("INSERT INTO users (#{attrs.keys.join(",")}) VALUES (#{quoted_attrs})")
  end

  def raw_select
    db_connection.execute("SELECT * FROM users").to_a
  end
end
