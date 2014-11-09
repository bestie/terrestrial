require "spec_helper"

require "sequel_mapper"

RSpec.describe SequelMapper::AssociationProxy do
  let(:proxy) {
    SequelMapper::AssociationProxy.new(lazy_enum)
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
      expect(proxy.to_a).to eq(data_set.to_a)
    end
  end

  describe "#each" do
    it "returns self" do
      expect(proxy.each).to be(proxy)
    end

    it "yeilds each element to the block" do
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
end
