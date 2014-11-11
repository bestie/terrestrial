require "spec_helper"

require "sequel_mapper"
require "support/graph_fixture"

RSpec.describe "Graph persistence" do
  include SequelMapper::GraphFixture

  subject(:graph) {
    SequelMapper::Graph.new(
      top_level_namespace: :users,
      datastore: datastore,
      relation_mappings: relation_mappings,
    )
  }

  let(:user) {
    graph.where(id: "user/1").fetch(0)
  }

  context "without accessing associations" do
    let(:modified_email) { "bestie+modified@gmail.com" }

    it "saves the root object" do
      user.email = modified_email
      graph.save(user)

      expect(datastore).to have_persisted(
        :users,
        hash_including(
          id: "user/1",
          email: modified_email,
        )
      )
    end

    it "doesn't send associated objects to the database as columns" do
      user.email = modified_email
      graph.save(user)

      expect(datastore).not_to have_persisted(
        :users,
        hash_including(
          posts: anything,
        )
      )
    end
  end

  context "modify shallow has many associated object" do
    let(:post) { user.posts.first }
    let(:modified_post_body) { "modified ur body" }

    it "saves the associated object" do
      post.body = modified_post_body
      graph.save(user)

      expect(datastore).to have_persisted(
        :posts,
        hash_including(
          id: post.id,
          subject: post.subject,
          author_id: post.author.id,
          body: modified_post_body,
        )
      )
    end
  end

  context "modify deeply nested has many associated object" do
    let(:comment) {
      user.posts.first.comments.to_a.last
    }

    let(:modified_comment_body) { "body moving, body moving" }

    it "saves the associated object" do
      comment.body = modified_comment_body
      graph.save(user)

      expect(datastore).to have_persisted(
        :comments,
        hash_including(
          {
            id: "comment/2",
            post_id: "post/1",
            commenter_id: "user/1",
            body: modified_comment_body,
          }
        )
      )
    end
  end

  context "modify the foreign_key of an object" do
    let(:original_author) { user }
    let(:new_author)      { graph.where(id: "user/2").first }
    let(:post)            { original_author.posts.first }

    it "persists the change in ownership" do
      post.author = new_author
      graph.save(user)

      expect(datastore).to have_persisted(
        :posts,
        hash_including(
          id: post.id,
          author_id: new_author.id,
        )
      )
    end

    it "removes the object form the original graph" do
      post.author = new_author
      graph.save(user)

      expect(original_author.posts.to_a.map(&:id))
        .not_to include("posts/1")
    end

    it "adds the object to the appropriate graph" do
      post.author = new_author
      graph.save(user)

      expect(new_author.posts.to_a.map(&:id))
        .to include("post/1")
    end
  end

  context "add a node to a has many assocation" do
    let(:new_post_attrs) {
      {
        id: "posts/neu",
        author: user,
        subject: "I am new",
        body: "new body",
        comments: [],
        categories: [],
      }
    }

    let(:new_post) {
      SequelMapper::StructFactory.new(
        SequelMapper::GraphFixture::Post
      ).call(new_post_attrs)
    }

    it "adds the object to the graph" do
      user.posts.push(new_post)

      expect(user.posts).to include(new_post)
    end

    it "persists the object" do
      user.posts.push(new_post)
      graph.save(user)

      expect(datastore).to have_persisted(
        :posts,
        hash_including(
          id: "posts/neu",
          author_id: user.id,
          subject: "I am new",
        )
      )
    end
  end

  context "remove an object from a has many association" do
    let(:post) { user.posts.first }

    it "removes the object from the graph" do
      user.posts.remove(post)

      expect(user.posts.map(&:id)).not_to include(post.id)
    end

    it "removes the object from the datastore on save" do
      user.posts.remove(post)
      graph.save(user)

      expect(datastore).not_to have_persisted(
        :posts,
        hash_including(
          id: post.id,
        )
      )
    end
  end

  context "modify a many to many relationhip" do
    let(:post)     { user.posts.first }

    context "remove a node" do
      it "mutates the graph" do
        category = post.categories.first
        post.categories.remove(category)

        expect(post.categories.map(&:id)).not_to include(category.id)
      end

      it "persists the change" do
        category = post.categories.first
        post.categories.remove(category)
        graph.save(user)

        expect(datastore).not_to have_persisted(
          :categories_to_posts,
          {
            post_id: post.id,
            category_id: category.id,
          }
        )
      end
    end

    context "add a node" do
      let(:post_with_one_category) { user.posts.to_a.last }
      let(:new_category) { user.posts.first.categories.to_a.first }

      it "mutates the graph" do
        post_with_one_category.categories.push(new_category)

        expect(post_with_one_category.categories.map(&:id))
          .to match_array(["category/1", "category/2"])
      end

      it "persists the change" do
        post_with_one_category.categories.push(new_category)
        graph.save(user)

        expect(datastore).to have_persisted(
          :categories_to_posts,
          {
            post_id: post_with_one_category.id,
            category_id: new_category.id,
          }
        )
      end
    end

    context "modify a node" do
      let(:category) { user.posts.first.categories.first }
      let(:modified_category_name) { "modified category" }

      it "mutates the graph" do
        category.name = modified_category_name

        expect(post.categories.first.name)
          .to eq(modified_category_name)
      end

      it "persists the change" do
        category.name = modified_category_name
        graph.save(user)

        expect(datastore).to have_persisted(
          :categories,
          {
            id: category.id,
            name: modified_category_name,
          }
        )
      end
    end
  end

  RSpec::Matchers.define :have_persisted do |relation_name, data|
    match do |datastore|
      datastore[relation_name].find { |record|
        if data.respond_to?(:===)
          data === record
        else
          data == record
        end
      }
    end

    failure_message do |datastore|
      "expected #{datastore[relation_name]} to have persisted #{data.inspect} in #{relation_name}"
    end

    failure_message_when_negated do |datastore|
      failure_message.gsub("to have", "not to have")
    end
  end
end
