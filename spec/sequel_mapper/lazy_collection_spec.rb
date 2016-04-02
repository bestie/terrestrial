require "spec_helper"

require "sequel_mapper/lazy_collection"

RSpec.describe Terrestrial::LazyCollection do
  let(:proxy) {
    Terrestrial::LazyCollection.new(
      database_enum,
      loader,
      mapper,
    )
  }

  let(:row1) { double(:row1) }
  let(:row2) { double(:row2) }
  let(:object1) { double(:object1) }
  let(:object2) { double(:object2) }
  let(:row_object_map) {
    {
      row1 => object1,
      row2 => object2,
    }
  }
  let(:collection_size) { row_object_map.size }

  let(:database_enum) { [row1, row2].each.lazy }

  let(:mapper) { double(:mapper) }

  let(:loader_count) { @loader_count }
  let(:loader) {
    @loader_count = 0

    ->(row) {
      @loader_count = @loader_count + 1
      row_object_map.fetch(row)
    }
  }

  it "is Enumerable" do
    expect(proxy).to be_a(Enumerable)
  end

  describe "#to_ary" do
    it "is equivalent to the original enumeration" do
      expect(proxy.to_ary).to eq([object1, object2])
    end

    it "implicitly coerces to Array" do
      new_object = Object.new

      expect([new_object].concat(proxy)).to eq([new_object, object1, object2])
    end
  end

  describe "#each" do
    it "iterates over all elements of the database_enum" do
      elements = []
      proxy.each { |x| elements.push(x) }

      expect(elements).to eq([object1, object2])
    end

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
        expect {
          proxy.each { |x| x }
        }.not_to change { loader_count }
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
        proxy.drop(1).each { |x| x }

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
end
