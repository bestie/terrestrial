require "support/object_graph_setup"

RSpec.shared_context "seed data setup" do
  include_context "object graph setup"

  before {
    seeded_records.each { |(namespace, record)|
      datastore[namespace].insert(record)
    }
  }

  let(:seeded_records) {
    [
      [ :users, hansel_record ],
      [ :posts, biscuits_post_record ],
      [ :posts, sleep_post_record ],
      [ :comments, biscuits_post_comment_record ],
      [ :categories, cat_biscuits_category_record ],
      [ :categories_to_posts, categories_to_posts_record ],
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

  let(:categories_to_posts_record) {
    {
      post_id: "posts/1",
      category_id: "categories_1",
    }
  }
end
