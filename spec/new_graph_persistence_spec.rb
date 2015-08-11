require "spec_helper"
require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/have_persisted_matcher"

RSpec.describe "Persist a new graph in empty datastore" do
  include_context "mapper setup"
  include_context "sequel persistence setup"

  before do
    truncate_tables
  end

  context "given a graph of new objects" do
    it "persists the root node" do
      user_mapper.save(hansel)

      expect(datastore).to have_persisted(:users, {
        id: hansel.id,
        first_name: hansel.first_name,
        last_name: hansel.last_name,
        email: hansel.email,
      })
    end

    it "persists one to many related nodes 1 level deep" do
      user_mapper.save(hansel)

      expect(datastore).to have_persisted(:posts, {
        id: "posts/1",
        subject: "Biscuits",
        body: "I like them",
        author_id: "users/1",
      })

      expect(datastore).to have_persisted(:posts, {
        id: "posts/2",
        subject: "Sleeping",
        body: "I do it three times purrr day",
        author_id: "users/1",
      })
    end

    it "persists one to many related nodes 2 levels deep" do
      user_mapper.save(hansel)

      expect(datastore).to have_persisted(:comments, {
        id: "comments/1",
        body: "oh noes",
        post_id: "posts/1",
        commenter_id: "users/1",
      })
    end

    it "persists many to many related nodes" do
      user_mapper.save(hansel)

      expect(datastore).to have_persisted(:categories, {
        id: "categories/1",
        name: "Cat biscuits",
      })
    end

    it "persists a 'join table' to faciliate many to many" do
      user_mapper.save(hansel)

      expect(datastore).to have_persisted(:categories_to_posts, {
        category_id: "categories/1",
        post_id: "posts/1",
      })
    end
  end

  after do |ex|
    puts $dumped.map(&:inspect).join("\n")
    require "pry"; binding.pry # DEBUG @bestie
  end
end
