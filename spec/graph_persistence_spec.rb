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
