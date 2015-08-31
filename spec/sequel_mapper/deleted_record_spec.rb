require "spec_helper"

require "sequel_mapper/deleted_record"

RSpec.describe SequelMapper::DeletedRecord do
  subject(:record) {
    SequelMapper::DeletedRecord.new(namespace, identity, raw_data)
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

  describe "#if_delete" do
    it "invokes the callback" do
      expect { |callback|
        record.if_delete(&callback)
      }.to yield_with_args(record)
    end
  end

  describe "#==" do
    context "with another record that deletes" do
      let(:comparitor) {
        record.merge({})
      }

      it "is equal" do
        expect(record.==(comparitor)).to be(true)
      end
    end

    context "with another record that does not delete" do
      let(:comparitor) {
        Class.new(SequelMapper::AbstractRecord) do
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
