require "spec_helper"

require "sequel_mapper/dirty_map"
require "sequel_mapper/upserted_record"
require "sequel_mapper/deleted_record"

RSpec.describe SequelMapper::DirtyMap do
  subject(:dirty_map) {
    SequelMapper::DirtyMap.new(storage)
  }

  let(:storage) { {} }

  let(:loaded_record) {
    create_record( namespace, identity_fields, attributes, depth)
  }

  let(:namespace) { :table_name }
  let(:identity_fields) { [:id] }
  let(:depth) { 0 }

  let(:attributes) {
    {
      id: "record/id",
      name: "record/name",
      email: "record/email",
    }
  }

  describe "#load" do
    it "adds the record to its storage" do
      dirty_map.load(loaded_record)

      expect(storage.values).to include(loaded_record)
    end

    it "returns the loaded record" do
      expect(dirty_map.load(loaded_record)).to eq(loaded_record)
    end
  end

  describe "#dirty" do
    let(:clean_record) {
      create_record(namespace, identity_fields, attributes, depth)
    }

    let(:dirty_record) {
      create_record(
        namespace,
        identity_fields,
        attributes.merge(name: "record/dirty_name"),
        depth,
      )
    }

    context "when the record has not been loaded (new record)" do
      it "return true" do
        expect(dirty_map.dirty?(clean_record)).to be(true)
      end
    end

    context "when a record with same identity has been loaded (existing record)" do
      before do
        dirty_map.load(loaded_record)
      end

      context "when the record is unchanged" do
        it "returns false" do
          expect(dirty_map.dirty?(clean_record)).to be(false)
        end
      end

      context "when the record's attributes are changed" do
        it "returns true" do
          expect(dirty_map.dirty?(dirty_record)).to be(true)
        end
      end

      context "when the record's attributes hash is mutated" do
        before do
          attributes.merge!(name: "new_value")
        end

        it "returns true" do
          expect(dirty_map.dirty?(clean_record)).to be(true)
        end
      end

      context "when a record's string value is mutated" do
        before do
          attributes.fetch(:name) << "MUTANT"
        end

        it "returns true" do
          expect(dirty_map.dirty?(clean_record)).to be(true)
        end
      end

      context "when record contains an unchanged subset of the fields loaded" do
        let(:partial_record) {
          create_record(
            namespace,
            identity_fields,
            partial_clean_attrbiutes,
            depth,
          )
        }

        let(:partial_clean_attrbiutes) {
          attributes.reject { |k, _v| k == :email }
        }

        it "return false" do
          expect(dirty_map.dirty?(partial_record)).to be(false)
        end
      end

      context "when record contains a changed subset of the fields loaded" do
        let(:partial_record) {
          create_record(
            namespace,
            identity_fields,
            partial_dirty_attrbiutes,
            depth,
          )
        }

        let(:partial_dirty_attrbiutes) {
          attributes
            .reject { |k, _v| k == :email }
            .merge(name: "record/changed_name")
        }

        it "return false" do
          expect(dirty_map.dirty?(partial_record)).to be(true)
        end
      end

      context "when record contains an unchanged superset of the fields loaded" do
        let(:super_record) {
          create_record(
            namespace,
            identity_fields,
            super_clean_attributes,
            depth,
          )
        }

        let(:super_clean_attributes) {
          attributes.merge(unknown_key: "record/unknown_value")
        }

        it "return true" do
          expect(dirty_map.dirty?(super_record)).to be(true)
        end
      end
    end

    context "#reject_unchanged_fields" do
      context "when the record has not been loaded (new record)" do
        it "returns an eqiuivalent record" do
          expect(dirty_map.reject_unchanged_fields(dirty_record))
            .to eq(dirty_record)
        end
      end

      context "when a record with same identity has been loaded (existing record)" do
        before do
          dirty_map.load(loaded_record)
        end

        context "with a equivalent record" do
          it "returns an empty record" do
            expect(dirty_map.reject_unchanged_fields(clean_record)).to be_empty
          end
        end

        context "a record with a changed field" do
          it "returns a record containing just that field" do
            expect(
              dirty_map
                .reject_unchanged_fields(dirty_record)
                .non_identity_attributes
            ).to eq( name: "record/dirty_name" )
          end
        end
      end
    end
  end

  def create_record(namespace, identity_fields, attributes, depth)
    SequelMapper::UpsertedRecord.new(
      namespace,
      identity_fields,
      attributes,
      depth,
    )
  end
end
