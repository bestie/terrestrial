require "spec_helper"

require "terrestrial/adapters/sequel_postgres_adapter"
require "terrestrial/upserted_record"

RSpec.describe Terrestrial::Adapters::SequelPostgresAdapter, backend: "sequel" do

  let(:adapter) { Terrestrial::Adapters::SequelPostgresAdapter.new(datastore) }

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

  describe "#unique_indexes" do
    before(:all) do
      adapter_support.create_tables(schema_with_unique_index.fetch(:tables))
      adapter_support.add_unique_indexes(schema_with_unique_index.fetch(:unique_indexes))
    end

    after(:all) do
      adapter_support.drop_tables(schema_with_unique_index.fetch(:tables).keys)
    end

    before(:each) { adapter_support.clean_table(:unique_index_table) }

    context "when the table has no primary key" do
      let(:table_name) { :unique_index_table }

      it "returns an array of the indexed fields" do
        expect(adapter.unique_indexes(table_name)).to eq([
          [:field_one, :field_two]
        ])
      end

      context "when there is no conflicting row" do
        let(:record) {
          create_record(field_one: "1", field_two: "2", text: "initial value")
        }

        it "upserts resulting in a new row" do
          expect { adapter.upsert(record) }
            .to change { datastore[:unique_index_table].count }
            .by(1)
        end
      end

      context "when a conflicting row" do
        let(:updated_record) {
          create_record(field_one: "1", field_two: "2", text: "new value")
        }

        before do
          record = create_record(field_one: "1", field_two: "2", text: "initial value")
          adapter.upsert(record)
        end

        it "upserts, updating the existing row" do
          expect { adapter.upsert(updated_record) }
            .to change { datastore[:unique_index_table].count }
            .by(0)

          expect(adapter[:unique_index_table].first.fetch(:text)).to eq("new value")
        end
      end
    end

    def create_record(values)
      Terrestrial::UpsertedRecord.new(
        :unique_index_table,
        [:field_one, :field_two],
        values,
      )
    end

    context "when the has a primary key and no other indexes" do
      let(:table_name) { :users }

      it "returns an empty array" do
        expect(adapter.unique_indexes(table_name)).to eq([])
      end
    end

    def adapter_support
      Terrestrial::SequelTestSupport
    end

    def schema_with_unique_index
      {
        tables: {
          unique_index_table: [
            { name: :field_one, type: String, options: { null: false } },
            { name: :field_two, type: String, options: { null: false } },
            { name: :text, type: String, options: { null: false } },
          ],
        },
        unique_indexes: [
          [:unique_index_table, :field_one, :field_two]
        ],
      }
    end
  end
end
