require "terrestrial"
require "terrestrial/configurations/conventional_configuration"

RSpec.describe "Factory error handling" do
  context "when the object factory raises an error" do
    before do
      seed_user(record)
      override_user_factory_with(just_throws_an_error_factory)
    end

    let(:just_throws_an_error_factory) {
      ->(*args) { raise original_error }
    }

    let(:original_error) {
      ArgumentError.new("wrong number of arguments (given 1, expected 0)")
    }

    it "raises a Terrestrial::Error with a helpful error message" do
      error = nil
      begin
        load_first_user
      rescue Terrestrial::Error => error
      end

      expect(error.message).to eq(
        [
          "Error loading record from `users` relation `#{record.inspect}`.",
          "Using: `#{just_throws_an_error_factory.inspect}`.",
          "Check that the factory is compatible.",
          "",
          "Caught error:",
          "ArgumentError wrong number of arguments (given 1, expected 0)",
        ].join("\n")
      )
    end

    it "raises an error with a backtrace that points to the client code, not the library code where it was wrapped" do
      error = nil
      begin
        load_first_user
      rescue Terrestrial::Error => error
      end

      expect(error.backtrace.first).to include(__FILE__)
      expect(error.backtrace.first).not_to include("terrestrial/lib")
    end
  end

  def record
    {
      id: "users/999",
      first_name: "Badger",
      last_name: "Smith",
      email: "b@smith.biz",
    }
  end

  def load_first_user
    @object_store[:users].first
  end

  def override_user_factory_with(factory)
    config = Terrestrial.config(datastore)
      .setup_mapping(:users) { |users|
        users.factory(factory)
      }

    @object_store = Terrestrial.object_store(config: config)
  end

  def seed_user(record)
    adapter_support.execute(
      "INSERT INTO USERS (#{record.keys.map(&:to_s).join(",")}) " \
      "VALUES ('#{record.values.join("','")}')"
    )
  end
end
