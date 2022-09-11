require "spec_helper"

require "terrestrial/adapters/active_record_postgres_adapter"

RSpec.describe Terrestrial::Adapters::ActiveRecordPostgresAdapter::Dataset, backend: "active_record" do
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

    it "combines with select without mutating" do
      d_id1 = dataset.where(id: 1)
      d_sfn = dataset.select([:first_name])
      d_id1_sfn = d_id1.select([:email])

      expect(dataset.to_sql).to eq(base_sql)
      expect(d_id1.to_sql).to eq(base_sql + ' WHERE "users"."id" = 1')
      expect(d_id1_sfn.to_sql).to eq('SELECT "users"."email" FROM "users" WHERE "users"."id" = 1')
    end

    # it "arel really?" do
    #   select = arel_table.project("*")
    #
    #   sw = select.clone.where(arel_table[:id].eq(1))
    #
    #   expect(sw.to_sql).not_to eq(select.to_sql)
    # end
  end
end
