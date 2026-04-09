RSpec.shared_context "unique index only schema" do
  before(:all) do
    adapter_support.create_tables(schema_with_unique_index.fetch(:tables))
    adapter_support.add_unique_indexes(schema_with_unique_index.fetch(:unique_indexes))
  end

  after(:all) do
    adapter_support.drop_tables(schema_with_unique_index.fetch(:tables).keys)
  end

  before(:each) { adapter_support.clean_tables([:unique_index_table]) }

  def create_record(values)
    Terrestrial::UpsertRecord.new(
      mapping,
      object,
      values,
      0,
    )
  end

  let(:object) { double(:object) }

  let(:mapping) {
    double(
      :mapping,
      namespace: :unique_index_table,
      primary_key: [],
      database_owned_fields: [],
      database_default_fields: [],
      post_save: nil,
    )
  }

  def schema_with_unique_index
    {
      tables: {
        unique_index_table: [
          { name: :field_one, type: String, options: { null: false } },
          { name: :field_two, type: String, options: { null: false } },
          { name: :text, type: String, options: { null: false } },
        ],
      },
      unique_indexes: [
        [:unique_index_table, :field_one, :field_two]
      ],
    }
  end
end
