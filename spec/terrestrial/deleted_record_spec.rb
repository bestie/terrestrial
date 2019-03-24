require "spec_helper"

require "terrestrial/deleted_record"

RSpec.describe Terrestrial::DeletedRecord do
  subject(:record) {
    Terrestrial::DeletedRecord.new(namespace, identity, raw_data)
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
end
