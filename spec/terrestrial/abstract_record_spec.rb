require "spec_helper"

require "terrestrial/record"

RSpec.describe Terrestrial::Record do
  subject(:record) {
    Terrestrial::Record.new(
      mapping,
      attributes,
    )
  }

  let(:mapping) {
    double(
      :mapping,
      {
        namespace: namespace,
        primary_key: primary_key_fields,
        database_owned_fields: [],
        database_default_fields: [],
      }
    )
  }

  let(:namespace) { double(:namespace) }
  let(:primary_key_fields) { [:id] }
  let(:depth) { 0 }

  let(:attributes) {
    {
      id: id,
      name: name,
    }
  }

  let(:id) { double(:id) }
  let(:name) { double(:name) }

  describe "#namespace" do
    it "returns the namespace" do
      expect(record.namespace).to eq(namespace)
    end
  end

  describe "#identity" do
    it "returns the primary key fields" do
      expect(record.identity).to eq(
        id: id,
      )
    end
  end

  describe "#updatable?" do
    context "when the record has attributes other than its identity attributes" do
      let(:record) {
        Terrestrial::Record.new(
          mapping,
          { id: "some-id", name: "some name" },
        )
      }

      it "returns true" do
        expect(record).to be_updatable
      end
    end

    context "when the record contains only identity attributes" do
      let(:record) {
        Terrestrial::Record.new(
          mapping,
          { id: "some-id" },
        )
      }

      it "returns false" do
        expect(record).not_to be_updatable
      end
    end
  end

  describe "#updatable_attributes" do
    it "filters out idetity attributes" do
      expect(record.updatable_attributes).not_to include(
        id: id,
      )
    end

    it "returns a hash of only non-identity attributes" do
      expect(record.updatable_attributes).to eq(
        name: name,
      )
    end
  end

  describe "#fetch" do
    it "delegates to the underlying Hash representation" do
      expect(record.fetch(:id)).to eq(id)
      expect(record.fetch(:name)).to eq(name)
      expect(record.fetch(:not_there, "nope")).to eq("nope")
      expect(record.fetch(:not_there) { "lord no" }).to eq("lord no")
    end
  end

  describe "#to_h" do
    it "returns a raw_data merged with identity" do
      expect(record.to_h).to eq(
        id: id,
        name: name,
      )
    end
  end

  describe "#reject" do
    it "returns a new record" do
      expect(record.reject { true }).to be_a(Terrestrial::Record)
    end

    it "rejects matching non-identity attributes" do
      filtered = record.reject { |k, _v| k == :name }

      expect(filtered.to_h).not_to include(:name)
    end

    it "does not yield identity fields for rejection" do
      captured = []

      record.reject { |k, v| captured << [k, v] }

      expect(captured).not_to include(:id1, :id2)
    end

    it "cannot reject the identity attributes" do
      filtered = record.reject { true }

      expect(filtered.to_h).to eq(
        id: id,
      )
    end
  end

  describe "#empty?" do
    context "when there are non-identity attributes" do
      it "returns false" do
        expect(record).not_to be_empty
      end
    end

    context "when there are only identity attributes" do
      let(:record) {
        Terrestrial::Record.new(
          mapping,
          { id: "some-id" },
        )
      }

      it "returns true" do
        expect(record).to be_empty
      end
    end
  end

  describe "#if_upsert" do
    it "returns self" do
      expect(
        record.if_upsert { |_| }
      ).to be(record)
    end

    it "does not call the block" do
      expect {
        record.if_upsert { |_| raise "Does not happen" }
      }.not_to raise_error
    end
  end

  describe "#if_delete" do
    it "returns self" do
      expect(
        record.if_delete { |_| }
      ).to be(record)
    end

    it "does not call the block" do
      expect {
        record.if_delete { |_| raise "Does not happen" }
      }.not_to raise_error
    end
  end

  describe "#merge" do
    let(:extra_data) {
      {
        location: location,
      }
    }

    let(:location) { double(:location) }

    it "returns a new record with same identity" do
      expect(record.merge(extra_data).identity).to eq(
        id: id,
      )
    end

    it "returns a new record with same namespace" do
      expect(
        record.merge(extra_data).namespace
      ).to eq(namespace)
    end

    it "returns a new record with merged data" do
      merged_record = record.merge(extra_data)

      expect(merged_record.to_h).to eq(
        id: id,
        name: name,
        location: location,
      )
    end

    it "does not mutate the original record" do
      expect {
        record.merge(extra_data)
      }.not_to change { record.to_h }
    end

    context "when attempting to overwrite the existing identity" do
      let(:extra_data) {
        {
          id1: double(:new_id),
          location: location,
        }
      }

      it "does not change the identity" do
        expect {
          record.merge(extra_data)
        }.not_to change { record.identity }
      end
    end
  end

  describe "#==" do
    context "compared to a record with the same attributes and mapping" do
      let(:other) { Terrestrial::Record.new(mapping, attributes) }

      it "is equal" do
        expect(record).to eq(other)
      end
    end

    context "compared to a record with the same mappiung different attributes" do
      let(:other) { Terrestrial::Record.new(mapping, other_attributes) }
      let(:other_attributes) { double(:other_attributes) }

      it "is equal" do
        expect(record).not_to eq(other)
      end
    end

    context "compared to a record with the same attributes and different mapping" do
      let(:other) { Terrestrial::Record.new(other_mapping, attributes) }
      let(:other_mapping) { double(:other_mapping) }

      it "is not equal" do
        expect(record).not_to eq(other)
      end
    end

    context "compared to something completely different" do
      it "is not equal" do
        expect(record).not_to eq("something completetly different")
      end
    end
  end
end
