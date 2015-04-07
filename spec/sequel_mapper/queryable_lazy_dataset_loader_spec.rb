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

  let(:row1) { double(:row1) }
  let(:row2) { double(:row2) }
  let(:object1) { double(:object1) }
  let(:object2) { double(:object2) }
  let(:collection_size) { 2 }

  let(:database_enum) { [row1, row2].each.lazy }

  let(:mapper) { double(:mapper) }
  let(:identity_func) { ->(x){x} }

  def loader
    @loader ||= begin
      @loader_count = 0

      ->(_) {
        @loader_count += 1
        [ object1, object2 ].fetch(@loader_count - 1)
      }
    end
  end

  def loader_count
    @loader_count
  end

  describe "#each" do
    context "when the collection is not loaded" do
      it "loads the collection on first call" do
        proxy.each { |x| x }

        expect(loader_count).to eq(collection_size)
      end
    end

    context "when the collection has already loaded (second call to #each)" do
      before do
        proxy.each { |x| x }
      end

      it "does not load a second time" do
        proxy.each { |x| x }

        expect(loader_count).to eq(collection_size)
      end
    end

    context "when #first has been called beforehand" do
      before do
        proxy.first
      end

      it "does not reload the first element of the collection" do
        proxy.each { |x| x }

        expect(loader_count).to eq(collection_size)
      end

      it "iterates over all elements" do
        elements = []
        proxy.each { |x| elements.push(x) }

        expect(elements).to eq([object1, object2])
      end
    end

    context "when drop has been called beforehand" do
      it "loads each object just once" do
        proxy.drop(1).each { |x| p "here #{x}" }

        expect(loader_count).to eq(collection_size)
      end
    end
  end

  describe "#first" do
    it "loads only the first object" do
      proxy.first

      expect(loader_count).to eq(1)
    end
  end

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
