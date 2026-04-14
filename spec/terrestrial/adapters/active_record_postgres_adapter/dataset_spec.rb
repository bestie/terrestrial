require "spec_helper"

require "terrestrial/adapters/active_record_postgres_adapter"

RSpec.describe Terrestrial::Adapters::ActiveRecordPostgresAdapter::Dataset, backend: "activerecord" do
  let(:db_connection) { Terrestrial::ActiveRecordTestSupport.db_connection }
  let(:adapter) { Terrestrial::Adapters::ActiveRecordPostgresAdapter.new(db_connection) }

  let(:dataset) { described_class.new(adapter, arel_table, arel_select) }
  let(:base_sql) { 'SELECT * FROM "users"' }

  let(:arel_table) { Arel::Table.new(:users) }
  let(:arel_select) { nil }

  context "base dataset" do
    it "produces a plain SELECT *" do
      expect(dataset.to_sql).to eq('SELECT * FROM "users"')
    end
  end

  describe "#select" do
    it "adds specific field selections" do
      expect(dataset.select([:id, :first_name]).to_sql)
        .to eq('SELECT "users"."id", "users"."first_name" FROM "users"')
    end

    it "replaces field selections" do
      ds = dataset
        .select(["id"])
        .select(["first_name"])

      expect(ds.to_sql).to eq('SELECT "users"."first_name" FROM "users"')
      expect(ds.to_sql).not_to include('"users"."id"')
    end

    it "can accept an array or single field" do
      string_arg_sql = dataset.select('id').to_sql
      array_arg_sql = dataset.select([:id]).to_sql
      expect(array_arg_sql).to eq(string_arg_sql)
    end
  end

  describe "#where" do
    it "returns a new dataset with an added constraint" do
      expect(dataset.where(id: 1).to_sql).to eq(
        'SELECT * FROM "users" WHERE "users"."id" = 1'
      )
    end

    it "returns a new copy of itself" do
      constrained_dataset = dataset.where(id: 1)
      expect(dataset).not_to be(constrained_dataset)
      expect(dataset.to_sql).not_to eq(constrained_dataset.to_sql)
    end

    it "can be chained for logical AND" do
      two_wheres = dataset.where(id: 1).where(id: 2)
      expect(two_wheres.to_sql).to include('"users"."id" = 1 AND "users"."id" = 2')
    end

    context "when #select is called on the dataset after #where" do
      it "does not mutate the starting dataset" do
        starting_dataset = dataset.where(id: 1)

        expect {
          dataset.select([:boop])
          starting_dataset.select([:first_name])
          starting_dataset.select([:email])
        }.not_to change { starting_dataset.to_sql }
      end
    end

    context "when #select is called on the dataset before #where" do
      it "does not mutate the starting dataset" do
        starting_dataset = dataset.select(:email)
        expect {
          dataset.where(id: 2)
          starting_dataset.where(id: 1)
          starting_dataset.select(:id)
        }.not_to change { starting_dataset.to_sql }
      end
    end

    it "combines with select without mutating" do
      d_id1 = dataset.where(id: 1)
      d_sfn = dataset.select([:first_name])
      d_id1_sfn = d_id1.select([:email])

      expect(dataset.to_sql).to eq(base_sql)
      expect(d_id1.to_sql).to eq(base_sql + ' WHERE "users"."id" = 1')
      expect(d_sfn.to_sql).to eq('SELECT "users"."first_name" FROM "users"')
      expect(d_id1_sfn.to_sql).to eq('SELECT "users"."email" FROM "users" WHERE "users"."id" = 1')
    end

    it "can handle Ruby primitives as values" do
      xmas_22 = "2022-12-25 00:00:00 UTC"
      xmas_23 = "2023-12-25 00:00:00 UTC"

      filtered = dataset.where(
        int_field: 1,
        float_field: 3.2,
        in_range_field: (5..8),
        in_set_int_field: [1,2,3],
        string_field: "string",
        string_field_matched: /string regex/,
        in_set_string_field: ["one", "two", "three"],
        time_field: Time.parse(xmas_22),
        date_field: Date.parse(xmas_22),
        date_time_field: DateTime.parse(xmas_22),
        nil_field: nil,
        bool_true_field: true,
        bool_false_field: false,
        in_range_time_field: (Time.parse(xmas_22)..Time.parse(xmas_23)),
      )

      aggregate_failures do
        expect(filtered.to_sql).to include(%@"int_field" = 1@)
        expect(filtered.to_sql).to include(%@"float_field" = 3.2@)
        expect(filtered.to_sql).to include(%@"in_range_field" BETWEEN 5 AND 8@)
        expect(filtered.to_sql).to include(%@"string_field" = 'string'@)
        expect(filtered.to_sql).to include(%@"string_field" = 'string'@)
        expect(filtered.to_sql).to include(%@"string_field_matched" ~* 'string regex'@)
        expect(filtered.to_sql).to include(%@"in_set_string_field" IN ('one', 'two', 'three'@)
        expect(filtered.to_sql).to include(%@"time_field" = '2022-12-25 00:00:00'@)
        expect(filtered.to_sql).to include(%@"date_field" = '2022-12-25'@)
        expect(filtered.to_sql).to include(%@"date_time_field" = '2022-12-25 00:00:00'@)
        expect(filtered.to_sql).to include(%@"nil_field" IS NULL@)
        expect(filtered.to_sql).to include(%@"bool_true_field" = TRUE@)
        expect(filtered.to_sql).to include(%@"bool_false_field" = FALSE@)
        expect(filtered.to_sql).to include(%@"in_range_time_field" BETWEEN '2022-12-25 00:00:00' AND '2023-12-25 00:00:00'@)
      end
    end
  end
end
