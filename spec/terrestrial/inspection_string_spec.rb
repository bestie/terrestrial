require "spec_helper"

require "terrestrial/inspection_string"

RSpec.describe Terrestrial::InspectionString do
  class SomeClass
  end

  describe "#inspect" do
    let(:test_class) { Class.new }
    let(:object) { test_class.new }

    context "when #inspectable_properties is not implemented or returns `[]`" do
      it "returns the regular inspection string" do
        original_inspection_string = object.inspect

        object.extend(Terrestrial::InspectionString)

        expect(object.inspect).to eq(original_inspection_string)
      end

      context "when class is not anonymous" do
        class TestClass; end
        let(:object) { TestClass.new }

        it "returns the regular inspection string" do
          original_inspection_string = object.inspect

          object.extend(Terrestrial::InspectionString)

          expect(object.inspect).to eq(original_inspection_string)
        end
      end
    end

    context "when #inspectable_properties returns an array of present instance variables" do
      class TestClass2
        include Terrestrial::InspectionString

        def initialize
          @one = "one value"
          @two = "two value"
          @three = "three value"
        end

        def inspectable_properties
          [:one, :two]
        end
      end
      let(:object) { TestClass2.new }

      it "contains the specified instance variable names and values" do
        expect(object.inspect).to include('one="one value" two="two value"')
      end

      it "does not contain other instance variable values" do
        expect(object.inspect).not_to include("three")
      end
    end
  end
end
