require "spec_helper"

require "terrestrial/upserted_record"

RSpec.describe Terrestrial::UpsertedRecord do
  subject(:record) {
    Terrestrial::UpsertedRecord.new(namespace, identity, raw_data)
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

  describe "#if_upsert" do
    it "invokes the callback" do
      expect { |callback|
        record.if_upsert(&callback)
      }.to yield_with_args(record)
    end
  end

  describe "#==" do
    context "with another record that upserts" do
      let(:comparitor) {
        record.merge({})
      }

      it "is equal" do
        expect(record.==(comparitor)).to be(true)
      end
    end

    context "with another record that does not upsert" do
      let(:comparitor) {
        Class.new(Terrestrial::AbstractRecord) do
          protected
          def operation
            :something_else
          end
        end
      }

      it "is not equal" do
        expect(record.==(comparitor)).to be(false)
      end
    end
  end
end
