require "spec_helper"

require "sequel_mapper/upserted_record"

RSpec.describe SequelMapper::UpsertedRecord do
  subject(:record) {
    SequelMapper::UpsertedRecord.new(namespace, identity, raw_data)
  }

  let(:namespace) { double(:namespace) }

  let(:identity) {
    { id: id }
  }

  let(:raw_data) {
    {
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
    it "returns the identity" do
      expect(record.identity).to eq(identity)
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

  describe "#if_upsert" do
    it "invokes the callback" do
      expect { |callback|
        record.if_upsert(&callback)
      }.to yield_with_args(record)
    end

    it "returns self" do
      expect(
        record.if_upsert { |_| }
      ).to be(record)
    end
  end

  describe "#if_delete" do
    it "returns self" do
      expect(
        record.if_delete { |_| }
      ).to be(record)
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
      expect(
        record.merge(extra_data).identity
      ).to eq(identity)
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
  end

  describe "#==" do
    context "when comparitor is of the wrong type" do
      it "is not equal" do
        expect(record.==(Object.new)).to be(false)
      end
    end

    context "when the operation type is equal" do
      context "when the combined `raw_data` and `identity` are equal" do
        let(:comparitor) { record.merge({}) }

        it "is equal" do
          expect(record.==(comparitor)).to be(true)
        end
      end

      context "when the combined `raw_data` and `identity` are not equal" do
        let(:comparitor) { record.merge(something_else: "i'm different") }

        it "is not equal" do
          expect(record.==(comparitor)).to be(false)
        end
      end
    end

    context "when the operation name differs" do
      let(:comparitor) {
        record_class_with_different_operation.new(namespace, identity, raw_data)
      }

      let(:record_class_with_different_operation) {
        Class.new(SequelMapper::UpsertedRecord) {
          def initialize(*args, &block)
            super
            @operation = :deleted
          end
        }
      }

      it "is not equal" do
        expect(record.==(comparitor)).to be(false)
      end
    end
  end
end
