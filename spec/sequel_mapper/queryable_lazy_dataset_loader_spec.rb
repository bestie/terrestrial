require "spec_helper"

require "sequel_mapper/queryable_lazy_dataset_loader"

RSpec.describe SequelMapper::QueryableLazyDatasetLoader do
  subject(:dataset_loader) {
    SequelMapper::QueryableLazyDatasetLoader.new(
      datastore_enum,
      object_factory_function,
      association_mapper,
    )
  }

  let(:datastore_enum)              { double(:datastore_enum, first: nil) }
  let(:object_factory_function)     { double(:object_factory_function, call: nil) }
  let(:association_mapper)          { double(:association_mapper) }

  describe "#first" do
    let(:first_row)    { double(:first_row) }
    let(:first_object) { double(:first_object) }

    before do
      allow(datastore_enum).to receive(:first).and_return(first_row)
      allow(object_factory_function).to receive(:call).and_return(first_object)
    end

    it "delegates to the datastore_enum" do
      dataset_loader.first

      expect(datastore_enum).to have_received(:first)
    end

    it "loads the data from the enum#first" do
      dataset_loader.first

      expect(object_factory_function).to have_received(:call).with(first_row)
    end

    it "returns the loaded object" do
      expect(dataset_loader.first).to be(first_object)
    end
  end
end
