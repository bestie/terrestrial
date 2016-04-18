require "support/sequel_persistence_setup"

require "terrestrial"
require "terrestrial/configurations/conventional_configuration"

RSpec.describe "factory error handling" do
  include_context "sequel persistence setup"

  context "factory with too few parameters" do
    before do
      seed_user(record)
      override_user_factory_with(no_parameters_factory)
    end

    let(:record) {
      {
        id: "users/999",
        first_name: "Badger",
        last_name: "Smith",
        email: "b@smith.biz",
      }
    }

    let(:no_parameters_factory) {
      ->() { }
    }

    it "raises a helpful error message" do
      error = nil
      begin
        load_first_user
      rescue Terrestrial::Error => error
      end

      expect(error.message).to eq(
        [
          "Error loading record from `users` relation `#{record.inspect}`.",
          "Using: `#{no_parameters_factory.inspect}`.",
          "Check that the factory is compatible.",
          "Got Error: ArgumentError wrong number of arguments (given 1, expected 0)",
        ].join("\n")
      )
    end
  end

  def load_first_user
    @object_store[:users].first
  end

  def override_user_factory_with(factory)
    config = Terrestrial.config(datastore)
      .setup_mapping(:users) { |users|
        users.factory(no_parameters_factory)
      }

    @object_store = Terrestrial.object_store(
      mappings: config,
      datastore: datastore,
    )
  end

  def seed_user(record)
    datastore[:users].insert(record)
  end
end
