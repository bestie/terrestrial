require "support/object_graph_setup"
RSpec.shared_context "seed data setup" do
  include_context "object graph setup"

  before {
    insert_records(datastore, seeded_records)
  }

  let(:seeded_records) {
    [
      [ :users, hansel_record ],
      [ :users, jasper_record ],
      [ :users, poppy_record ],
      [ :posts, biscuits_post_record ],
      [ :posts, sleep_post_record ],
      [ :posts, catch_frogs_post_record ],
      [ :comments, biscuits_post_comment_record ],
      [ :categories, cat_biscuits_category_record ],
      [ :categories, eating_and_sleeping_category_record ],
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
    }
  }

  let(:sleep_post_record) {
    {
      id: "posts/2",
      subject: "Sleeping",
      body: "I do it three times purrr day",
      author_id: "users/1",
    }
  }

  let(:catch_frogs_post_record) {
    {
      id: "posts/3",
      subject: "Catching frongs",
      body: "I love them while at the same time I hate them",
      author_id: "users/2",
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
    ]
  }
end
