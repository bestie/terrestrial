require "spec_helper"

require "sequel_mapper/queryable_lazy_dataset_loader"

RSpec.describe SequelMapper::QueryableLazyDatasetLoader do
  let(:proxy) {
    SequelMapper::QueryableLazyDatasetLoader.new(
      database_enum,
      loader,
      mapper,
    )
  }

  let(:row) { double(:row) }
  let(:object) { double(:object) }
  let(:loader) { ->(_) { object } }
  let(:database_enum) { [row].each.lazy }

  let(:mapper) { double(:mapper) }

  describe "#loaded?" do
    context "before an item in the collection has been yielded" do
      it "is not loaded" do
        expect(proxy.loaded?).to be(false)
      end
    end

    context "after the collection has been mapped" do
      before do
        proxy.to_a
      end

      it "is loaded" do
        expect(proxy.loaded?).to be(true)
      end
    end

    context "after calling first" do
      before do
        proxy.first
      end

      it "is loaded" do
        expect(proxy.loaded?).to be(true)
      end
    end

    context "after iterating over the collection" do
      before do
        proxy.each do |obj|
          # NO OP
        end
      end

      it "is loaded" do
        expect(proxy.loaded?).to be(true)
      end
    end
  end
end
