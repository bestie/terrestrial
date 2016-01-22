require "spec_helper"

require "sequel_mapper/flat_map_expandable"

RSpec.describe SequelMapper::FlatMapExpandable do
  subject(:lazy_nested_collection) {
    CollectionProxy.new([
      double(:post_1, comments: CollectionProxy.new([comment_1])),
      double(:post_2, comments: CollectionProxy.new([comment_2])),
    ])
  }

  let(:comment_1) { double(:comment_1) }
  let(:comment_2) { double(:comment_2) }

  it "expands the nested collections" do
    expect(lazy_nested_collection.flat_map(&:comments)).to eq(
      [
        comment_1,
        comment_2,
      ]
    )
  end

  CollectionProxy = Class.new do
    include Enumerable
    include SequelMapper::FlatMapExpandable
    def initialize(collection)
      @collection = collection
    end

    def each(&block)
      @collection.each(&block)
    end
  end
end
