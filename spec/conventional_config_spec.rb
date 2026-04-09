require "spec_helper"
require "ostruct"

require "support/object_store_setup"
require "support/seed_data_setup"
require "terrestrial"

require "terrestrial/configurations/conventional_configuration"

RSpec.describe "Conventional configs" do
  include_context "object store setup"
  include_context "seed data setup"

  after do
    restore_constants
  end

  let(:user_struct_class) { Struct.new(:id, :first_name, :last_name, :email, :posts) }

  it "fixes some spooky test suite issue" do
  end

  context "specify a class name" do
    before do
      set_constant(:NamedUserClass, user_struct_class)
    end

    let(:object_store) {
      Terrestrial.object_store(config: override_config)
    }

    let(:override_config) {
      Terrestrial::config(datastore)
        .setup_mapping(:users) { |users|
          users.class_name("NamedUserClass")
        }
    }

    it "detects the struct and switches to StructFactory" do
      new_user = user_struct_class.new("user/struct", "first", "last", "email", [])
      object_store[:users].save(new_user)

      user = object_store[:users].where(id: "user/struct").first

      expect(user.class).to be(user_struct_class)
      expect(user.id).to eq("user/struct")
      expect(user.first_name).to eq("first")
    end
  end

  context "without specifing a class or factory" do
    context "User class is a struct" do
      before do
        replace_constant(:User, user_struct_class)
      end

      let(:user_struct_class) { Struct.new(:id, :first_name, :last_name, :email, :posts) }

      it "detects the struct and switches to StructFactory" do
        new_user = User.new("user/struct", "first", "last", "email", [])
        object_store[:users].save(new_user)

        user = object_store[:users].where(id: "user/struct").first

        expect(user.class).to be(user_struct_class)
        expect(user.id).to eq("user/struct")
        expect(user.first_name).to eq("first")
      end
    end
  end

  def restore_constants
    replaced_constants.each do |name, value|
      set_constant(name, value)
    end
  end

  def replace_constant(name, value)
    replaced_constants[name] = Object.const_get(name)

    set_constant(name, value)
  end

  def replaced_constants
    @replaced_constants ||= {}
  end

  def set_constant(name, value)
    if Object.const_defined?(name)
      Object.send(:remove_const, name)
    end
    Object.const_set(name, value)
  end
end
