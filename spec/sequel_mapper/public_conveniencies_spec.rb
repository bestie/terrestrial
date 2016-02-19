require "spec_helper"

require "sequel_mapper/public_conveniencies"

RSpec.describe SequelMapper::PublicConveniencies do
  subject(:conveniences) {
    Module.new.extend(SequelMapper::PublicConveniencies)
  }

  describe "#mapper" do
    let(:datastore) {
      {
        things: [ thing_record ],
      }
    }

    let(:mapper_config) {
      {
        things: double(
          :thing_config,
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
      expect(
        conveniences
          .mapper(
            config: mapper_config,
            datastore: datastore,
            name: mapping_name,
          )
          .all.first.fetch(:id)
      ).to eq("THE THING")
    end
  end
end
