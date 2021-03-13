require "support/object_graph_setup"
require "support/seed_records"

RSpec.shared_context "seed data setup" do
  include_context "object graph setup"

  before {
    seeded_records.each do |(namespace, record)|
      datastore[namespace].insert(record)
    end
  }

  let(:seeded_records) {
    [
      [ :users, SeedRecords.hansel_record ],
      [ :users, SeedRecords.jasper_record ],
      [ :users, SeedRecords.poppy_record ],
      [ :posts, SeedRecords.biscuits_post_record ],
      [ :posts, SeedRecords.sleep_post_record ],
      [ :posts, SeedRecords.catch_frogs_post_record ],
      [ :posts, SeedRecords.chew_up_boxes_post_record ],
      [ :comments,   SeedRecords.biscuits_post_comment_record ],
      [ :categories, SeedRecords.cat_biscuits_category_record ],
      [ :categories, SeedRecords.eating_and_sleeping_category_record ],
      [ :categories, SeedRecords.hunting_category_record ],
      [ :categories, SeedRecords.messing_stuff_up_category_record ],
      *SeedRecords.categories_to_posts_records.map { |record|
        [ :categories_to_posts, record ]
      },
    ]
  }

end
