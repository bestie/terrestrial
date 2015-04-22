require "spec_helper"

require "spec_helper"
require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"

RSpec.describe "Proxying associations" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  context "of type `has_many`" do
    subject(:mapper) { user_mapper }

    let(:user) {
      mapper.where(id: "user/1").first
    }

    let(:posts) { user.posts }

    describe "limiting datastore reads" do
      context "when loading the root node" do
        it "only performs one read" do
          user

          expect(query_counter.read_count).to eq(1)
        end
      end

      context "when getting a reference to an association proxy" do
        before { user }

        it "does no additional reads" do
          expect{
            user.posts
          }.to change { query_counter.read_count }.by(0)
        end
      end

      context "when iteratiing over a has many association" do
        before { posts }

        it "does a single additional read for the assocation collection" do
          expect {
            user.posts.each { |x| x }
          }.to change { query_counter.read_count }.by(1)
        end

        context "when doing this more than once" do
          before do
            posts.each { |x| x }
          end

          it "performs no additional reads" do
            expect {
              user.posts.each { |x| x }
            }.not_to change { query_counter.read_count }
          end
        end
      end

      context "when getting a reference to a many to many assocation" do
        before { post }

        let(:post) { user.posts.first }

        it "does no additional reads" do
          expect {
            post.categories
          }.to change { query_counter.read_count }.by(0)
        end
      end

      context "when iterating over a many to many assocation" do
        let(:category_count) { 3 }

        it "does 1 read" do
          post = user.posts.first

          expect {
            post.categories.each { |x| x }
          }.to change { query_counter.read_count }.by(1)
        end
      end
    end
  end
end
