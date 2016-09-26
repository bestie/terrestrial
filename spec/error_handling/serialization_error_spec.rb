require "support/object_store_setup"
require "support/sequel_persistence_setup"

RSpec.describe "Serialization error handling" do
  include_context "object store setup"
  context "when a domain object is incompatible with its serializer" do
    before do
      override_user_serializer_with(incompatible_custom_serializer)
    end

    let(:user) { Object.new }

    let(:incompatible_custom_serializer) {
      ->(x) { raise "I am incompatible" }
    }

    it "rescues and re-raises a more detailed error" do
      error = nil
      begin
        save_user
      rescue Terrestrial::SerializationError => error
      end

      expect(error.message).to eq(
        [
          "Error serializing object with mapping `users` `#{user.inspect}`.",
          "Using serializer: `#{incompatible_custom_serializer.inspect}`.",
          "Check the specified serializer can transform objects into a Hash.",
          "Got Error: RuntimeError I am incompatible",
        ].join("\n")
      )
    end

    # TODO: make configuration easier override
    def override_user_serializer_with(serializer)
      config = Terrestrial.config(datastore)
      .setup_mapping(:users) { |users|
        users.serializer(serializer)
      }

      @object_store = Terrestrial.object_store(
        mappings: config,
        datastore: datastore,
      )
    end

    def save_user
      @object_store[:users].save(user)
    end
  end
end
