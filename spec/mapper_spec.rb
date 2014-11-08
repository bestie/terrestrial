require "spec_helper"

class Mapper
  def initialize(datastore:, top_level_namespace:, relation_mappings:)
    @top_level_namespace = top_level_namespace
    @datastore = datastore
    @relation_mappings = relation_mappings
  end

  attr_reader :top_level_namespace, :datastore, :relation_mappings
  private     :top_level_namespace, :datastore, :relation_mappings

  def where(criteria)
    datastore[top_level_namespace]
      .where(criteria)
      .map(&method(:load))
  end

  private

  def load(row)
    relation = relation_mappings.fetch(:users)

    relation.fetch(:factory).call(row)
  end

  class StructFactory
    def initialize(struct_class)
      @constructor = struct_class.method(:new)
      @members = struct_class.members
    end

    attr_reader :constructor, :members
    private     :constructor, :members

    def call(data)
      constructor.call(
        *members.map { |m| data.fetch(m, nil) }
      )
    end
  end

  class MockSequel
    def initialize(relations)
      @relations = relations
    end

    def [](table_name)
      Relation.new(@relations.fetch(table_name))
    end

    class Relation
      include Enumerable

      def initialize(rows)
        @rows = rows
      end

      def where(criteria, &block)
        if block
          raise NotImplementedError.new("Block filtering not implemented")
        end

        self.class.new(equality_filter(criteria))
      end

      def to_a
        @rows
      end

      def each(&block)
        to_a.each(&block)
      end

      private

      def equality_filter(criteria)
        @rows.select { |row|
          criteria.all? { |k, v|
            row.fetch(k) == v
          }
        }
      end
    end
  end
end

RSpec.describe "Object mapping" do

  User = Struct.new(:id, :first_name, :last_name, :email, :messages)
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
              relation: :messages,
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

    let(:message_1_entity) {
      Message.new(
        "message/1", "user/2", "user/1", "Object mapping", "It is often tricky",
      )
    }

    let(:user_1_entity) {
      User.new("user/1", "Stephen", "Best", "bestie@gmail.com")
    }

    let(:user_query) {
      mapper.where(id: "user/1")
    }

    it "finds data via the storage adapter" do
      expect(user_query.count).to be 1
    end

    it "maps the raw data from the store into domain objects" do
      expect(user_query).to eq([user_1_entity])
    end

    it "handles has_many relationships" do
      expect(user_query.fetch(0).messages.first).to eq(message_entity)
    end
  end
end
