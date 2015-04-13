require "spec_helper"
require "support/mapper_setup"

RSpec.describe "Dump a plain object graph to flat data" do
  include_context "mapper setup"

  let(:hansel) {
    factories.fetch(:users).call(
      id: "users/1",
      first_name: "Hansel",
      last_name: "Trickett",
      email: "hansel@tricketts.org",
      posts: [
        biscuits_post,
        sleep_post,
      ],
    )
  }

  let(:biscuits_post) {
    factories.fetch(:posts).call(
      id: "posts/1",
      subject: "Biscuits",
      body: "I like them",
      comments: [
        biscuits_post_comment,
      ],
      categories: [
        cat_biscuits_category,
      ],
    )
   }

   let(:sleep_post) {
     factories.fetch(:posts).call(
       id: "posts/2",
       subject: "Sleeping",
       body: "I do it three times purrr day",
       comments: [],
     )
   }

  let(:biscuits_post_comment) {
    factories.fetch(:comments).call(
      id: "comments/1",
      body: "oh noes",
    )
  }

  let(:cat_biscuits_category) {
    factories.fetch(:categories).call(
      id: "categories/1",
      name: "Cat biscuits",
    )
  }

  def annoying_circluar_bit
    biscuits_post_comment.commenter = hansel
    cat_biscuits_category.posts = [ biscuits_post ]
  end

  before do
    annoying_circluar_bit
  end

  describe "dump single object" do
    let(:user) {
      factories.fetch(:users).call(
        id: "users/1",
        first_name: "Hansel",
        last_name: "Trickett",
        email: "hansel@tricketts.org",
      )
    }

    it "dumps the object to a data structure" do
      expect(mappers[:users].dump(user)).to eq([
        SequelMapper::NamespacedRecord.new(
          :users,
          {
            id: "users/1",
            first_name: "Hansel",
            last_name: "Trickett",
            email: "hansel@tricketts.org",
          }
        )
      ])
    end
  end

  describe "dump object graph" do
    it "dumps the posts association" do
      expect(
        mappers[:users].dump(hansel)
      ).to include(
        SequelMapper::NamespacedRecord.new(
          :posts,
          {
            id: "posts/1",
            subject: "Biscuits",
            body: "I like them",
            author_id: "users/1",
          },
        ),
        SequelMapper::NamespacedRecord.new(
          :posts,
          {
            id: "posts/2",
            subject: "Sleeping",
            body: "I do it three times purrr day",
            author_id: "users/1",
          },
        ),
      )
    end

    it "dumps the comments association" do
      expect(
        mappers[:users].dump(hansel)
      ).to include(
        SequelMapper::NamespacedRecord.new(
          :comments,
          {
            id: "comments/1",
            body: "oh noes",
            post_id: "posts/1",
            commenter_id: "users/1",
          },
        ),
      )
    end

    it "dumps the categories" do
      expect(
        mappers[:users].dump(hansel)
      ).to include(
        SequelMapper::NamespacedRecord.new(
          :categories,
          {
            id: "categories/1",
            name: "Cat biscuits",
          },
        )
      )
    end

    it "dumps the 'join table' records" do
      expect(
        mappers[:users].dump(hansel)
      ).to include(
        SequelMapper::NamespacedRecord.new(
          :categories_to_posts,
          {
            category_id: "categories/1",
            post_id: "posts/1",
          },
        )
      )
    end

    it "duplicates the root object (but that's ok)" do
      dupe = mappers[:users].dump(hansel)
        .group_by { |x| x }
        .map { |k, v| [k, v.length] }
        .select { |o, count| count > 1 }
        .first
        .first

      expect(dupe.fetch(:id)).to eq("users/1")
    end
  end
end
