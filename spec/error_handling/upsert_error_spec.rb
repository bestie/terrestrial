require "support/object_store_setup"
require "support/sequel_persistence_setup"

RSpec.describe "Upsert error handling" do
  include_context "object store setup"
  include_context "sequel persistence setup"

  let(:user) { Object.new }

  context "serializer returns an extra field not in the schema" do
    before do
      use_custom_serializer(extra_field_serializer)
    end

    let(:extra_field_serializer) {
      ->(_x) {
        {
          extra_field_that_does_not_match_column: "some value",
          id: "users/999",
          first_name: "Hansel",
          last_name: "Trickett",
          email: "hansel@tricketts.org",
        }
      }
    }

    it "filters the serialization result and raises no error" do
      expect { save_user }.not_to raise_error
    end
  end

  context "serialization result omits required fields" do
    before do
      use_custom_serializer(missing_id_serializer)
    end

    let(:missing_id_serializer) {
      ->(_x) { serialization_result }
    }

    let(:serialization_result) {
      object_attributes.reject { |k,v| k == :id }
    }

    let(:object_attributes) {
      {
        id: "users/999",
        first_name: "Hansel",
        last_name: "Trickett",
        email: "hansel@tricketts.org",
      }
    }

    it "filters the serialization result and raises no error" do
      error = nil
      begin
        save_user
      rescue Terrestrial::UpsertError => error
      end

      expect(error.message).to eq(
        [
          "Error upserting record into `users` with data `#{serialization_result}`.",
          "Got Error: Sequel::NotNullConstraintViolation PG::NotNullViolation: ERROR:  null value in column \"id\" violates not-null constraint",
          "DETAIL:  Failing row contains (null, Hansel, Trickett, hansel@tricketts.org).\n",
        ].join("\n")
      )
    end
  end

  def save_user
    @object_store[:users].save(user)
  end

  def use_custom_serializer(serializer)
    config = Terrestrial.config(datastore)
      .setup_mapping(:users) { |users|
        users.serializer(serializer)
      }

    @object_store = Terrestrial.object_store(
      mappings: config,
      datastore: datastore,
    )
  end
end
