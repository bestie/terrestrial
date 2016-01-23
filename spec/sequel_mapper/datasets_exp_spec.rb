require "spec_helper"
require "support/mapper_setup"
require "support/seed_data_setup"
require "support/sequel_persistence_setup"

RSpec.describe "datasets and stuff" do
  include_context "mapper setup"
  include_context "seed data setup"
  include_context "sequel persistence setup"

  def insert_records(*_)
  end

  class Dataset < SequelMapper::Dataset
    def initialize(name, records)
      @name = name
      @records = records
    end
    attr_reader :name

    def each(&block)
      $them_qs ||= 0
      $them_qs += 1
      records.each(&block)
      self
    end

    def new(records)
      self.class.new(name, records)
    end
  end

  def dataset(name, array)
    Dataset.new(name,array)
  end

  let(:datastore) {
    {
      users: dataset(:users,[
        hansel_record,
        jasper_record,
        poppy_record,
      ]),
      posts: dataset(:posts, [
        biscuits_post_record,
        sleep_post_record,
        catch_frogs_post_record,
      ]),
      comments: dataset(:comments, [
        biscuits_post_comment_record,
      ]),
      categories: dataset(:categories, [
        cat_biscuits_category_record,
        eating_and_sleeping_category_record,
      ]),
      categories_to_posts: dataset(:categories_to_posts, categories_to_posts_records),
    }
  }

  it "handles an in memory dataset" do
    expect(
      user_mapper.eager_load(posts: { categories: {} }).first.posts.flat_map(&:categories).map(&:id)
    ).to eq(["categories/1", "categories/2", "categories/2"])
  end
end
