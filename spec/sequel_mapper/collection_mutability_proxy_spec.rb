require "spec_helper"

require "sequel_mapper/collection_mutability_proxy"

RSpec.describe SequelMapper::CollectionMutabilityProxy do
  let(:proxy) {
    SequelMapper::CollectionMutabilityProxy.new(lazy_enum)
  }

  let(:lazy_enum) { data_set.each.lazy }
  let(:data_set) { (0..9) }

  def id
    ->(x) { x }
  end

  it "is Enumerable" do
    expect(proxy).to be_a(Enumerable)
  end

  describe "#to_a" do
    it "is equivalent to the original enumeration" do
      expect(proxy.map(&id)).to eq(data_set.to_a)
    end
  end

  describe "#each" do
    context "when called with a block" do
      it "returns self" do
        expect(proxy.each(&id)).to eq(proxy)
      end

      it "yields each element to the block" do
        yielded = []

        proxy.each do |element|
          yielded.push(element)
        end

        expect(yielded).to eq(data_set.to_a)
      end

      context "when calling each more than once" do
        before do
          proxy.each { |x| nil }
          proxy.each { |x| nil }
        end

        it "rewinds the enumeration on each call" do
          expect(proxy.map(&id)).to eq(data_set.to_a)
        end
      end
    end

    context "when called without a block" do
      it "returns an enumerator" do
        expect(proxy.each).to be_a(Enumerator)
      end
    end
  end

  describe "#remove" do
    it "returns self" do
      expect(proxy.remove(3)).to be(proxy)
    end

    context "after removing a element from the enumeration" do
      before do
        proxy.remove(3)
      end

      it "skips that element in the enumeration" do
        expect(proxy.map(&id)).to eq([0,1,2,4,5,6,7,8,9])
      end
    end
  end

  describe "#push" do
    context "after pushing another element into the enumeration" do
      before do
        proxy.push(new_value)
      end

      let(:new_value) { double(:new_value) }

      it "does not alter the other elements" do
        expect(proxy.map(&id)[0..-2]).to eq([0,1,2,3,4,5,6,7,8,9])
      end

      it "appends the element to the enumeration" do
        expect(proxy.map(&id).last).to eq(new_value)
      end
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
        proxy.map(&id)
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
