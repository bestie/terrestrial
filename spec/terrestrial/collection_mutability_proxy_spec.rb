require "spec_helper"

require "terrestrial/collection_mutability_proxy"

RSpec.describe Terrestrial::CollectionMutabilityProxy do
  let(:proxy) {
    Terrestrial::CollectionMutabilityProxy.new(lazy_enum)
  }

  let(:lazy_enum) { data_set.lazy }
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

  describe "#to_ary" do
    it "is equivalent to the original enumeration" do
      expect(proxy.to_ary).to eq(data_set.to_a)
    end

    it "implicitly coerces to Array" do
      expect([-1].concat(proxy)).to eq([-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
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

    context "when a new element is pushed into the collection" do
      let(:new_element) { double(:new_element) }

      before do
        proxy.push(new_element)
      end

      it "adds the new element to the enumeration" do
        expect(proxy.to_a.last).to eq(new_element)
      end
    end
  end

  describe "#_loaded_nodes" do
    let(:lazy_enum) {
      LoadableCollectionDouble.new(
        data_set.each.lazy,
        loaded_nodes,
      )
    }

    let(:loaded_nodes) { data_set.take(2) }

    it "returns an enumerator of loaded nodes" do
      expect(proxy._loaded_nodes).to be_a(Enumerator)
      expect(proxy._loaded_nodes.to_a).to eq(loaded_nodes.to_a)
    end
  end

  describe "#_deleted_nodes" do
    context "before any nodes have been deleted" do
      it "returns an empty enumerator" do
        expect(proxy._deleted_nodes.to_a).to be_empty
      end
    end

    context "after some nodes have been deleted" do
      before do
        deleted_nodes.each { |node| proxy.delete(node) }
      end

      let(:deleted_nodes) { [4, 0] }

      context "when called without a block" do
        it "returns an enumerator of deleted nodes" do
          expect(proxy._deleted_nodes).to be_a(Enumerator)
          expect(proxy._deleted_nodes.to_a).to eq(deleted_nodes)
        end
      end
    end
  end

  describe "#delete" do
    it "returns self" do
      expect(proxy.delete(3)).to be(proxy)
    end

    context "after removing a element from the enumeration" do
      before do
        proxy.delete(3)
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

  class LoadableCollectionDouble
    def initialize(collection, loaded_collection)
      @collection = collection
      @loaded_collection = loaded_collection
    end

    def each(&block)
      @collection.each(&block)
    end

    def each_loaded(&block)
      @loaded_collection.each(&block)
    end
  end
end
