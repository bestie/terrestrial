require "spec_helper"

require "mapper"

RSpec.describe "Object mapping" do

  User = Struct.new(:id, :first_name, :last_name, :email, :received_messages)
  Message = Struct.new(:id, :sender_id, :recipient_id, :subject, :body)

  describe "Straight trivial mapping" do
    subject(:mapper) {
      Mapper.new(
        top_level_namespace: :users,
        datastore: datastore,
        relation_mappings: relation_mappings,
      )
    }

    let(:datastore) {
      Mapper::MockSequel.new(
        {
          users: [
            user_1_data,
            user_2_data,
          ],
          messages: [
            message_1_data,
          ],
        }
      )
    }

    let(:relation_mappings) {
      {
        users: {
          factory: user_factory,
          # columns: [],
          has_many: {
            received_messages: {
              relation_name: :messages,
              foreign_key: :recipient_id,
            },
          },
        },
        messages: {
          factory: message_factory,
          # columns: [],
        },
      }
    }

    let(:user_factory){
      Mapper::StructFactory.new(User)
    }

    let(:message_factory){
      Mapper::StructFactory.new(Message)
    }

    let(:user_1_data) {
      {
        id: "user/1",
        first_name: "Stephen",
        last_name: "Best",
        email: "bestie@gmail.com",
      }
    }

    let(:user_2_data) {
      {
        id: "user/2",
        first_name: "Hansel",
        last_name: "Trickett",
        email: "hansel@gmail.com",
      }
    }

    let(:message_1_data) {
      {
        id: "message/1",
        recipient_id: "user/1",
        sender_id: "user/2",
        subject: "Object mapping",
        body: "It is often tricky",
      }
    }

    let(:user_query) {
      mapper.where(id: "user/1")
    }

    it "finds data via the storage adapter" do
      expect(user_query.count).to be 1
    end

    it "maps the raw data from the store into domain objects" do
      expect(user_query.fetch(0).id).to eq("user/1")
      expect(user_query.fetch(0).first_name).to eq("Stephen")
    end

    it "handles has_many associations" do
      expect(user_query.fetch(0).received_messages.first.subject)
        .to eq("Object mapping")
    end
  end
end
