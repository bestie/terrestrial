require "spec_helper"

require "support/have_persisted_matcher"
require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"

require "sequel_mapper/configurations/conventional_configuration"

RSpec.describe "Config override" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  let(:user) { user_mapper.where(id: "users/1").first }

  context "with an object that has private fields" do
    let(:user_serializer) {
      ->(object) {
        object.to_h.merge(
          first_name: "I am a custom serializer",
          last_name: "and i don't care about facts",
        )
      }
    }

    before do
      mappings
        .fetch(:users)
        .instance_variable_set(:@serializer, user_serializer)
    end

    context "when saving the object" do
      it "uses the custom serializer" do
        user.first_name = "This won't work"
        user.last_name = "because the serialzer is weird"

        user_mapper.save(user)

        expect(datastore).to have_persisted(:users, hash_including(
          id: user.id,
          first_name: "I am a custom serializer",
          last_name: "and i don't care about facts",
        ))
      end
    end
  end
end
