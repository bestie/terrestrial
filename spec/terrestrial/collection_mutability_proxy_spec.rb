require "spec_helper"

require "terrestrial/collection_mutability_proxy"

RSpec.describe Terrestrial::CollectionMutabilityProxy do
  let(:proxy) {
    Terrestrial::CollectionMutabilityProxy.new(lazy_enum)
  }

  let(:lazy_enum) { data_set.lazy }
  let(:data_set) { (0..9) }

  it "is Enumerable" do
    expect(proxy).to be_a(Enumerable)
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
    context "when called without a block" do
      it "returns an enumerator of all nodes" do
        expect(proxy.each).to be_a(Enumerator)

        expect(proxy.each.to_a).to eq(data_set.to_a)
      end
    end

    context "when called with a block" do
      it "returns self" do
        expect(proxy.each { |x| nil }).to be(proxy)
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
          yielded = []

          proxy.each do |element|
            yielded.push(element)
          end

          expect(yielded).to eq(data_set.to_a)
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
    let(:deleted_node) { 3 }

    it "returns self" do
      expect(proxy.delete(deleted_node)).to be(proxy)
    end

    it "removes that node from the enumeration" do
      proxy.delete(3)

      expect(proxy.to_a).to eq([0,1,2,4,5,6,7,8,9])
    end
  end

  describe "#push" do
    context "after pushing another element into the collection" do
      before do
        proxy.push(new_value)
      end

      let(:new_value) { double(:new_value) }

      it "returns self" do
        expect(proxy.push(new_value)).to be(proxy)
      end

      it "retains the existing nodes" do
        expect(proxy.to_a[0..-2]).to eq([0,1,2,3,4,5,6,7,8,9])
      end

      it "appends the new node to the collection" do
        expect(proxy.to_a.last).to eq(new_value)
      end
    end
  end

  describe "#+" do
    let(:additional_nodes) { [10, 11, 12] }

    it "returns a new collection" do
      expect(proxy + additional_nodes).to be_a(Terrestrial::CollectionMutabilityProxy)
      expect(proxy + additional_nodes).not_to be(proxy)
      expect(proxy + additional_nodes).not_to be(additional_nodes)
    end

    it "concatenates with self" do
      expect(
        (proxy + additional_nodes).to_a
      ).to eq([0,1,2,3,4,5,6,7,8,9,10,11,12])
    end

    it "does not mutate self" do
      expect {
        proxy + additional_nodes
      }.not_to change { proxy.to_a }
    end

    context "after pushing a node" do
      before do
        proxy.push(pushed_node)
      end

      let(:pushed_node) { 99 }

      it "retains the pushed nodes" do
        expect(proxy + additional_nodes).to include(pushed_node)
      end
    end

    context "after deleting a node" do
      before do
        proxy.delete(deleted_node)
      end

      let(:deleted_node) { 9 }

      it "retains the deletion of the nodes" do
        expect((proxy + additional_nodes).to_a).not_to include(deleted_node)
      end
    end

    context "push to the original after adding" do
      it "does not change the new collection" do
        new_collection = proxy + additional_nodes

        expect {
          proxy.push(99)
        }.not_to change { new_collection.to_a }
      end
    end

    context "delete from the original after adding" do
      it "does not change the new collection" do
        new_collection = proxy + additional_nodes

        expect {
          proxy.delete(0)
        }.not_to change { new_collection.to_a }
      end
    end
  end

  describe "#-" do
    let(:subtracted_nodes) { [4, 6, 8, 9, 0] }

    it "returns a new collection" do
      expect(proxy - subtracted_nodes).to be_a(Terrestrial::CollectionMutabilityProxy)
      expect(proxy - subtracted_nodes).not_to be(proxy)
      expect(proxy - subtracted_nodes).not_to be(subtracted_nodes)
    end

    it "subtracts from self" do
      expect(
        (proxy - subtracted_nodes).to_a
      ).to eq([1,2,3,5,7])
    end

    it "does not mutate self" do
      expect {
        proxy - subtracted_nodes
      }.not_to change { proxy.to_a }
    end

    context "after pushing a node" do
      before do
        proxy.push(pushed_node)
      end

      let(:pushed_node) { 99 }

      it "retains the pushed nodes" do
        expect(proxy - subtracted_nodes).to include(pushed_node)
      end
    end

    context "after deleting a node" do
      before do
        proxy.delete(deleted_node)
      end

      let(:deleted_node) { 2 }

      it "retains the deletion of the nodes" do
        expect((proxy - subtracted_nodes).to_a).not_to include(deleted_node)
      end
    end

    context "push to the original after subtracting" do
      it "does not change the new collection" do
        new_collection = proxy - subtracted_nodes

        expect {
          proxy.push(99)
        }.not_to change { new_collection.to_a }
      end
    end

    context "delete from the original after subtracting" do
      it "does not change the new collection" do
        new_collection = proxy - subtracted_nodes

        expect {
          proxy.delete(1)
        }.not_to change { new_collection.to_a }
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
