module SeedRecords
  module_function

  def hansel_record
    {
      id: "users/1",
      first_name: "Hansel",
      last_name: "Trickett",
      email: "hansel@tricketts.org",
    }
  end

  def jasper_record
    {
      id: "users/2",
      first_name: "Jasper",
      last_name: "Trickett",
      email: "jasper@tricketts.org",
    }
  end

  def poppy_record
    {
      id: "users/3",
      first_name: "Poppy",
      last_name: "Herzog",
      email: "poppy@herzog.info",
    }
  end

  def biscuits_post_record
    {
      id: "posts/1",
      subject: "Biscuits",
      body: "I like them",
      author_id: "users/1",
      created_at: Time.parse("2015-09-02T15:00:00+01:00"),
    }
  end

  def sleep_post_record
    {
      id: "posts/2",
      subject: "Sleeping",
      body: "I do it three times purrr day",
      author_id: "users/1",
      created_at: Time.parse("2015-09-03T15:00:00+01:00"),
    }
  end

  def catch_frogs_post_record
    {
      id: "posts/3",
      subject: "Catching frongs",
      body: "I love them while at the same time I hate them",
      author_id: "users/2",
      created_at: Time.parse("2015-09-05T15:00:00+01:00"),
    }
  end

  def chew_up_boxes_post_record
    {
      id: "posts/4",
      subject: "Chewing up boxes",
      body: "I love them, and yet I destory them",
      author_id: "users/2",
      created_at: Time.parse("2015-09-10T11:00:00+01:00"),
    }
  end

  def biscuits_post_comment_record
    {
      id: "comments/1",
      body: "oh noes",
      post_id: "posts/1",
      commenter_id: "users/1",
    }
  end

  def cat_biscuits_category_record
    {
      id: "categories/1",
      name: "Cat biscuits",
    }
  end

  def eating_and_sleeping_category_record
    {
      id: "categories/2",
      name: "Eating and sleeping",
    }
  end

  def hunting_category_record
    {
      id: "categories/3",
      name: "Hunting",
    }
  end

  def messing_stuff_up_category_record
    {
      id: "categories/4",
      name: "Messing stuff up",
    }
  end

  def categories_to_posts_records
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
  end
end

