require "spec_helper"

require "sequel_mapper/public_conveniencies"

RSpec.describe SequelMapper::PublicConveniencies do
  subject(:conveniences) {
    Module.new.extend(SequelMapper::PublicConveniencies)
  }

  class MockDatastore < DelegateClass(Hash)
    def transaction(&block)
      block.call
    end
  end

  describe "#mappers" do
    let(:datastore) {
      MockDatastore.new(
        {
          things: [ thing_record ],
        }
      )
    }

    let(:mapper_config) {
      {
        things: double(
          :thing_config,
          name: mapping_name,
          namespace: :things,
          fields: [:id],
          associations: [],
          primary_key: [],
          factory: ->(x){x}
        )
      }
    }

    let(:mapping_name) { :things }

    let(:thing_record) {
      {
        id: "THE THING",
      }
    }

    it "returns a mapper for the specified mapping" do
      mappers = conveniences.mappers(
        mappings: mapper_config,
        datastore: datastore,
      )

      expect(
        mappers[:things].all.first.fetch(:id)
      ).to eq("THE THING")
    end
  end
end
