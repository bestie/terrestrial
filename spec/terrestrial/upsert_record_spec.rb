require "spec_helper"

require "terrestrial/upsert_record"

RSpec.describe "Terrestrial::UpsertRecord" do
  subject(:record) { Terrestrial::UpsertRecord.new(mapping, object, attributes, depth) }

  let(:mapping) { double(:mapping) }

  let(:object) { double(:object) }
  let(:depth) { 1 }
  let(:attributes) {
    {
      id: id,
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
end
