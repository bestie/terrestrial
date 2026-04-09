require "spec_helper"

require "terrestrial/error"

RSpec.describe "Errors" do

  def where_original_error_happens
    raise RuntimeError.new("original message")
  end

  def record
    { id: "i am a record" }
  end

  describe Terrestrial::UpsertError do
    def library_stuff
      where_original_error_happens
    rescue RuntimeError => error
      raise Terrestrial::UpsertError.new("relation_name", record, error)
    end

    it "presents with original error's backtrace, does not misdriect to where it is caught" do
      begin
        library_stuff
      rescue => error
      end

      expect(error.backtrace.first).not_to include("library_stuff")
      expect(error.backtrace.first).to include("where_original_error_happens")
    end
  end

  describe Terrestrial::LoadError do
    def library_stuff
      where_original_error_happens
    rescue RuntimeError => error
      raise Terrestrial::LoadError.new("relation_name", "factory", record, error)
    end

    it "presents with original error's backtrace, does not misdriect to where it is caught" do
      begin
        library_stuff
      rescue => error
      end

      expect(error.backtrace.first).not_to include("library_stuff")
      expect(error.backtrace.first).to include("where_original_error_happens")
    end
  end

  describe Terrestrial::SerializationError do
    def library_stuff
      where_original_error_happens
    rescue RuntimeError => error
      raise Terrestrial::SerializationError.new("relation_name", "serializer", record, [:id], error)
    end

    it "presents with original error's backtrace, does not misdriect to where it is caught" do
      begin
        library_stuff
      rescue => error
      end

      expect(error.backtrace.first).not_to include("library_stuff")
      expect(error.backtrace.first).to include("where_original_error_happens")
    end
  end
end
