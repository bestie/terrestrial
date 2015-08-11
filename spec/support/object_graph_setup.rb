require "sequel_mapper/serializer"
require "sequel_mapper/struct_factory"

RSpec.shared_context "object graph setup" do

  before do
    setup_circular_references_avoiding_stack_overflow
  end

  def setup_circular_references_avoiding_stack_overflow
    biscuits_post_comment.commenter = hansel
    cat_biscuits_category.posts = [ biscuits_post ]
  end

  User ||= Struct.new(:id, :first_name, :last_name, :email, :posts, :comments)
  Post ||= Struct.new(:id, :author, :subject, :body, :comments, :categories)
  Comment ||= Struct.new(:id, :post, :commenter, :body)
  Category ||= Struct.new(:id, :name, :posts)

  let(:factories) {
    {
      users: SequelMapper::StructFactory.new(User),
      posts: SequelMapper::StructFactory.new(Post),
      comments: SequelMapper::StructFactory.new(Comment),
      categories: SequelMapper::StructFactory.new(Category),
      categories_to_posts: ->(x){x},
      noop: ->(x){x},
    }
  }

  let(:default_serializer) {
    ->(fields) {
      ->(object) {
        SequelMapper::Serializer.new(fields, object).to_h
      }
    }
  }

  let(:null_serializer) {
    ->(_fields) {
      ->(x){x}
    }
  }

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
       categories: [
        chilling_category,
      ],
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

  let(:chilling_category) {
    factories.fetch(:categories).call(
      id: "categories/2",
      name: "Chillaxing",
    )
  }
end
