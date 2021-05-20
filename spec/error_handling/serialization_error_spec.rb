require "support/object_store_setup"

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

      expect(error.message).to eq(<<~MESSAGE
        RuntimeError I am incompatible

        Terrestrial couldn't serialize object `#{user.inspect}`.
        Terrestrial attempted to serialize it as part of mapping `users` with `#{incompatible_custom_serializer.inspect}`.

        Suggested actions:

          - Check that mapping `users` is supposed to handle objects with class `#{user.class}`.
            If not you may have put an object in the wrong field e.g. `user.apples = oranges`.

          - Check that the serializer returns a hash-like object with following keys:
            `[:id, :first_name, :last_name, :email]`

        Serialzation is where Terrestrial attempts to convert your object into a hash of database-friendly values before writing them to the database.
        A typical serialzer will take a domain object and return a hash with a key for each column of the database table.
        MESSAGE
      )
    end

    # TODO: make configuration easier override
    def override_user_serializer_with(serializer)
      config = Terrestrial.config(datastore)
      .setup_mapping(:users) { |users|
        users.serializer(serializer)
      }

      @object_store = Terrestrial.object_store(config: config)
    end

    def save_user
      @object_store[:users].save(user)
    end
  end
end
