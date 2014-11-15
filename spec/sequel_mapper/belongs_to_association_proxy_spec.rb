require "spec_helper"

require "sequel_mapper/belongs_to_association_proxy"

RSpec.describe BelongsToAssociationProxy do
  subject(:proxy) { BelongsToAssociationProxy.new(object_loader) }

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
end
