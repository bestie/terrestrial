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


  subject(:user_mapper) {
    SequelMapper.mapper(
      config: mapper_config,
      name: :users,
      datastore: datastore,
    )
  }

  let(:mapper_config) {
    SequelMapper::Configurations::ConventionalConfiguration.new(datastore)
      .setup_mapping(:users) { |users|
        users.has_many :posts, foreign_key: :author_id
      }
  }

  let(:user) { user_mapper.where(id: "users/1").first }

  context "with an object that has private fields" do
    let(:user_class) {
      Class.new(User) {
        private :first_name
        private :last_name

        def full_name
          [first_name, last_name].join(" ")
        end
      }
    }

    let(:user_serializer) {
      ->(object) {
        object.to_h.merge(
          first_name: "I am a custom serializer",
          last_name: "and i don't care about facts",
        )
      }
    }

    before do
      mapper_config.setup_mapping(:users) do |config|
        config.factory(user_class)
        config.serializer(user_serializer)
      end
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
