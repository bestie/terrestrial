require "spec_helper"

require "sequel_mapper"
require "support/database_fixture"

RSpec.describe "Configuration override" do
  include SequelMapper::DatabaseFixture

  subject(:mapper) { mapper_fixture }

  let(:user) { mapper.where(id: "user/1").first }

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
      ->(fields, object) {
        public_field_names = fields.select { |f| object.public_methods.include?(f) }

        first_name, last_name = object.full_name.split(" ")

        private_fields = {
          first_name: first_name,
          last_name: last_name,
        }

        public_fields = Hash[
          public_field_names.map { |field_name|
            [field_name, object.public_send(field_name)]
          }
        ]

        public_fields.merge(private_fields)
      }
    }

    before do
      mapper_config.setup_mapping(:users) do |config|
        config.factory(user_class)
        config.serializer(user_serializer)
      end
    end


    context "when saving the object" do
      it "uses a custom serializer" do
        user.first_name = "NEWNAME"
        mapper.save(user)

        expect(
          datastore[:users].where(id: "user/1").first.fetch(:first_name)
        ).to eq("NEWNAME")
      end
    end
  end
end
