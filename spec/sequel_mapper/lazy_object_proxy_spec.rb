require "spec_helper"

require "sequel_mapper/lazy_object_proxy"

RSpec.describe LazyObjectProxy do
  subject(:proxy) { LazyObjectProxy.new(object_loader) }

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
end
