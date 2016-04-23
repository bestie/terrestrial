require "spec_helper"

require "terrestrial/public_conveniencies"
require "ostruct"

RSpec.describe Terrestrial::PublicConveniencies do
  subject(:conveniences) {
    Module.new.extend(Terrestrial::PublicConveniencies)
  }

  class MockDatastore < DelegateClass(Hash)
    def transaction(&block)
      block.call
    end
  end

  describe "#object_store" do
    let(:datastore) {
      MockDatastore.new(
        {
          things: [ thing_record ],
        }
      )
    }

    let(:mappings) {
      {
        things: double(
          :thing_config,
          name: mapping_name,
          namespace: :things,
          fields: [:id],
          associations: [],
          primary_key: [],
          load: thing_object,
        )
      }
    }

    let(:mapping_name) { :things }

    let(:thing_record) {
      {
        id: "THE THING",
      }
    }

    let(:thing_object) {
      OpenStruct.new(thing_record)
    }

    it "returns an object store for given mappings" do
      object_store = conveniences.object_store(
        mappings: mappings,
        datastore: datastore,
      )

      expect(
        object_store[:things].all.first.id
      ).to eq("THE THING")
    end
  end
end
