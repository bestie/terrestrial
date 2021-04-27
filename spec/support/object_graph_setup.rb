require "terrestrial/serializer"
require "terrestrial/struct_factory"

RSpec.shared_context "object graph setup" do

  before do
    setup_circular_references_avoiding_stack_overflow
  end

  def setup_circular_references_avoiding_stack_overflow
    biscuits_post.author = hansel
    sleep_post.author = hansel

    hansel.posts = [
      biscuits_post,
      sleep_post,
    ]

    biscuits_post_comment.commenter = hansel
    cat_biscuits_category.posts = [ biscuits_post ]
  end

  class PlainObject
    def self.with_members(*list, &block)
      Class.new(self).tap { |klass|
        klass.instance_variable_set(:@members, list)
        klass.class_exec(&block) if block
        klass.send(:attr_accessor, *list)
      }
    end

    def self.members
      @members
    end

    def initialize(attrs)
      if members.sort != attrs.keys.sort
        missing = (members - attrs.keys).sort
        unexpected = (attrs.keys - members).sort
        raise(ArgumentError.new(
          "#{self.class} initialized with incorrect arguments." \
          "Missing: #{missing}. " \
          "Unexpected: #{unexpected}. " \
          "Received: #{attrs.keys}."
        ))
      end

      members.each { |member| send("#{member}=", attrs.fetch(member)) }
    end

    def members
      self.class.members
    end

    def to_h
      Hash[members.map { |field| [field, send(field)] }]
    end
  end

  User ||= PlainObject.with_members(:id, :first_name, :last_name, :email, :posts)
  Post ||= PlainObject.with_members(:id, :author, :subject, :body, :comments, :categories, :created_at, :updated_at)
  Comment ||= PlainObject.with_members(:id, :commenter, :body)
  Category ||= PlainObject.with_members(:id, :name, :posts)

  let(:hansel) {
    User.new(
      id: "users/1",
      first_name: "Hansel",
      last_name: "Trickett",
      email: "hansel@tricketts.org",
      posts: [],
    )
  }

  let(:biscuits_post) {
    Post.new(
      id: "posts/1",
      author: nil,
      subject: "Biscuits",
      body: "I like them",
      comments: [
        biscuits_post_comment,
      ],
      categories: [
        cat_biscuits_category,
      ],
      created_at: Time.parse("2015-09-05T15:00:00+01:00"),
      updated_at: Time.parse("2015-09-05T15:00:00+01:00"),
    )
  }

  let(:sleep_post) {
    Post.new(
      id: "posts/2",
      author: nil,
      subject: "Sleeping",
      body: "I do it three times purrr day",
      comments: [],
      categories: [
        chilling_category,
      ],
      created_at: Time.parse("2015-09-02T15:00:00+01:00"),
      updated_at: Time.parse("2015-09-02T15:00:00+01:00"),
    )
  }

  let(:biscuits_post_comment) {
    Comment.new(
      id: "comments/1",
      body: "oh noes",
      commenter: nil,
    )
  }

  let(:cat_biscuits_category) {
    Category.new(
      id: "categories/1",
      name: "Cat biscuits",
      posts: [],
    )
  }

  let(:chilling_category) {
    Category.new(
      id: "categories/2",
      name: "Chillaxing",
      posts: [],
    )
  }
end
