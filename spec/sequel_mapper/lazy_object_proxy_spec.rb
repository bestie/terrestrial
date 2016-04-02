require "spec_helper"

require "terrestrial/lazy_object_proxy"

RSpec.describe Terrestrial::LazyObjectProxy do
  subject(:proxy) {
    Terrestrial::LazyObjectProxy.new(
      object_loader,
      key_fields,
    )
  }

  let(:id) { double(:id) }
  let(:key_fields)      { { id: id } }
  let(:object_loader)   { double(:object_loader, call: proxied_object) }
  let(:proxied_object)  { double(:proxied_object, name: name) }
  let(:name)            { double(:name) }

  describe "#__getobj__" do
    it "loads the object" do
      proxy.__getobj__

      expect(object_loader).to have_received(:call)
    end

    it "returns the proxied object" do
      expect(proxy.__getobj__).to be(proxied_object)
    end
  end

  context "when no method is called on it" do
    it "does not call the loader" do
      proxy

      expect(object_loader).not_to have_received(:call)
    end
  end

  context "when a missing method is called on the proxy" do
    it "is a true decorator" do
      expect(proxied_object).to receive(:arbitrary_message)

      proxy.arbitrary_message
    end

    it "loads the object" do
      proxy.name

      expect(object_loader).to have_received(:call)
    end

    it "returns delegates the message to the object" do
      args = [ double, double ]
      proxy.name(*args)

      expect(proxied_object).to have_received(:name).with(*args)
    end

    it "returns the objects return value" do
      expect(proxy.name).to eq(name)
    end

    context "when calling a method twice" do
      it "loads the object once" do
        proxy.name
        proxy.name

        expect(object_loader).to have_received(:call)
      end
    end
  end

  describe "#loaded?" do
    context "before the object is loaded" do
      it "returns false" do
        expect(proxy).not_to be_loaded
      end
    end

    context "after the object is loaded" do
      def force_object_load(object)
        object.__getobj__
      end

      before { force_object_load(proxy) }

      it "returns true" do
        expect(proxy).to be_loaded
      end
    end
  end

  describe "key fields" do
    context "when key fields are provided before load (such as from foreign key)" do
      it "does not load the object when that field is accessed" do
        proxy.id

        expect(proxy).not_to be_loaded
      end

      it "returns the given value" do
        expect(proxy.id).to be(id)
      end
    end
  end

  describe "#respond_to?" do
    context "when method corresponds to a key field" do
      it "does not the load the object" do
        proxy.respond_to?(:id)

        expect(proxy).not_to be_loaded
      end

      it "repsonds to the method" do
        expect(proxy).to respond_to(:id)
      end
    end

    context "when the method is not a key field" do
      it "loads the object" do
        proxy.respond_to?(:something_arbitrary)

        expect(proxy).to be_loaded
      end

      context "when lazy proxied object does respond to the method" do
        it "responds to the method" do
          expect(proxy).to respond_to(:name)
        end
      end

      context "when lazy proxied object does not respond to the method" do
        it "does not respond to the method" do
          expect(proxy).not_to respond_to(:something_arbitrary)
        end
      end
    end
  end
end
