require "spec_helper"

require "sequel_mapper/abstract_record"

RSpec.describe SequelMapper::AbstractRecord do
  subject(:record) {
    SequelMapper::AbstractRecord.new(namespace, primary_key_fields, raw_data)
  }

  let(:namespace) { double(:namespace) }
  let(:primary_key_fields) { [ :id1, :id2 ] }

  let(:raw_data) {
    {
      id1: id1,
      id2: id2,
      name: name,
    }
  }

  let(:id1) { double(:id1) }
  let(:id2) { double(:id2) }
  let(:name) { double(:name) }

  describe "#namespace" do
    it "returns the namespace" do
      expect(record.namespace).to eq(namespace)
    end
  end

  describe "#identity" do
    it "returns the primary key fields" do
      expect(record.identity).to eq(
        id1: id1,
        id2: id2,
      )
    end
  end

  describe "#fetch" do
    it "delegates to the underlying Hash representation" do
      expect(record.fetch(:id1)).to eq(id1)
      expect(record.fetch(:name)).to eq(name)
      expect(record.fetch(:not_there, "nope")).to eq("nope")
      expect(record.fetch(:not_there) { "lord no" }).to eq("lord no")
    end
  end

  describe "#to_h" do
    it "returns a raw_data merged with identity" do
      expect(record.to_h).to eq(
        id1: id1,
        id2: id2,
        name: name,
      )
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
        id1: id1,
        id2: id2,
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
        id1: id1,
        id2: id2,
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
    context "super class contract" do
      let(:comparitor) { record.merge({}) }

      it "raises NotImplementedError" do
        expect{
          record == comparitor
        }.to raise_error(NotImplementedError)
      end

      context "when subclassed" do
        subject(:record) {
          record_subclass.new(namespace, primary_key_fields, raw_data)
        }

        let(:record_subclass) {
          Class.new(SequelMapper::AbstractRecord) {
            protected

            def operation
              :do_a_thing
            end
          }
        }

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
            record_class_with_different_operation.new(namespace, primary_key_fields, raw_data)
          }

          let(:record_class_with_different_operation) {
            Class.new(SequelMapper::AbstractRecord) {
              protected
              def operation
                :do_a_different_thing
              end
            }
          }

          it "is not equal" do
            expect(record.==(comparitor)).to be(false)
          end
        end
      end
    end
  end
end
