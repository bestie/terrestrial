require "support/object_store_setup"
require "terrestrial/inspection_string"

RSpec.describe "Upsert error handling" do
  include_context "object store setup"
  let(:user) { double(:user) }

  context "with an record that raises error on persistence" do
    before do
      use_custom_serializer( ->(_) { unpersistable_record } )
    end
    let(:unpersistable_record) { UnpersistableRecord.new(original_error) }
    let(:original_error) { RuntimeError.new("Cannot upsert") }

    it "raises an UpsertError with detail of the original error" do
      error = nil
      begin
        save_user
      rescue Terrestrial::UpsertError => error
      end

      expect(error.message).to eq(
        [
          "Error upserting record into `users` with data `#{unpersistable_record}`.",
          "Got Error: #{original_error.class} #{original_error.message}",
        ].join("\n")
      )
    end
  end

  class UnpersistableRecord
    include Terrestrial::InspectionString

    def initialize(error)
      @error = error
    end

    def to_h
      # This is used in error reporting
      self
    end

    def method_missing(*_)
      # Raising on anything else ensures a problem while persisting
      raise_if_upserting
      self
    end

    private

    def raise_if_upserting
      raise(@error) if caller.any? { |line| /if_upsert/ === line }
    end
  end

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

    it "raises an UpsertError with detail of the original error", backend: "sequel" do
      error = nil
      begin
        save_user
      rescue Terrestrial::UpsertError => error
      end

      aggregate_failures do
        expect(error.message).to start_with("Error upserting record into `users` with data `#{serialization_result}`.")
        expect(error.message).to include("Got Error: Sequel::NotNullConstraintViolation")
        expect(error.message).to include("in column \"id\"")
        expect(error.message).to include("DETAIL:  Failing row contains (null, Hansel, Trickett, hansel@tricketts.org)")
      end
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

    @object_store = Terrestrial.object_store(config: config)
  end
end
