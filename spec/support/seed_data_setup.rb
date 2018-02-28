require "support/object_graph_setup"
RSpec.shared_context "seed data setup" do
  include_context "object graph setup"

  before {
    seeded_records.each do |(namespace, record)|
      datastore[namespace].insert(record)
    end
  }

  let(:seeded_records) {
    [
      [ :users, hansel_record ],
      [ :users, jasper_record ],
      [ :users, poppy_record ],
      [ :posts, biscuits_post_record ],
      [ :posts, sleep_post_record ],
      [ :posts, catch_frogs_post_record ],
      [ :posts, chew_up_boxes_post_record ],
      [ :comments, biscuits_post_comment_record ],
      [ :categories, cat_biscuits_category_record ],
      [ :categories, eating_and_sleeping_category_record ],
      [ :categories, hunting_category_record ],
      [ :categories, messing_stuff_up_category_record ],
      *categories_to_posts_records.map { |record|
        [ :categories_to_posts, record ]
      },
    ]
  }

  let(:hansel_record) {
    {
      id: "users/1",
      first_name: "Hansel",
      last_name: "Trickett",
      email: "hansel@tricketts.org",
    }
  }

  let(:jasper_record) {
    {
      id: "users/2",
      first_name: "Jasper",
      last_name: "Trickett",
      email: "jasper@tricketts.org",
    }
  }

  let(:poppy_record) {
    {
      id: "users/3",
      first_name: "Poppy",
      last_name: "Herzog",
      email: "poppy@herzog.info",
    }
  }

  let(:biscuits_post_record) {
    {
      id: "posts/1",
      subject: "Biscuits",
      body: "I like them",
      author_id: "users/1",
      created_at: Time.parse("2015-09-02T15:00:00+01:00"),
    }
  }

  let(:sleep_post_record) {
    {
      id: "posts/2",
      subject: "Sleeping",
      body: "I do it three times purrr day",
      author_id: "users/1",
      created_at: Time.parse("2015-09-03T15:00:00+01:00"),
    }
  }

  let(:catch_frogs_post_record) {
    {
      id: "posts/3",
      subject: "Catching frongs",
      body: "I love them while at the same time I hate them",
      author_id: "users/2",
      created_at: Time.parse("2015-09-05T15:00:00+01:00"),
    }
  }

  let(:chew_up_boxes_post_record) {
    {
      id: "posts/4",
      subject: "Chewing up boxes",
      body: "I love them, and yet I destory them",
      author_id: "users/2",
      created_at: Time.parse("2015-09-10T11:00:00+01:00"),
    }
  }

  let(:biscuits_post_comment_record) {
    {
      id: "comments/1",
      body: "oh noes",
      post_id: "posts/1",
      commenter_id: "users/1",
    }
  }

  let(:cat_biscuits_category_record) {
    {
      id: "categories/1",
      name: "Cat biscuits",
    }
  }

  let(:eating_and_sleeping_category_record) {
    {
      id: "categories/2",
      name: "Eating and sleeping",
    }
  }

  let(:hunting_category_record) {
    {
      id: "categories/3",
      name: "Hunting",
    }
  }

  let(:messing_stuff_up_category_record) {
    {
      id: "categories/4",
      name: "Messing stuff up",
    }
  }

  let(:categories_to_posts_records) {
    [
      {
        post_id: "posts/1",
        category_id: "categories/1",
      },
      {
        post_id: "posts/1",
        category_id: "categories/2",
      },
      {
        post_id: "posts/2",
        category_id: "categories/2",
      },
      {
        post_id: "posts/3",
        category_id: "categories/2",
      },
      {
        post_id: "posts/3",
        category_id: "categories/3",
      },
      {
        post_id: "posts/4",
        category_id: "categories/3",
      },
      {
        post_id: "posts/4",
        category_id: "categories/4",
      },
    ]
  }
end
