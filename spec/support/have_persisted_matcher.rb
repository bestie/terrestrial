RSpec::Matchers.define :have_persisted do |relation_name, data_or_matcher|
  match do |datastore|
    @all_records = adapter_support.execute("SELECT * FROM #{relation_name}").to_a

    # === works for RSpec matchers and like == for hashes
    @all_records.any? { |record| data_or_matcher === record.symbolize_keys }
  end

  failure_message do |datastore|
    "expected to have persisted #{data_or_matcher.inspect} in #{relation_name}.\n" +
      "Found:\n" +
      @all_records.map(&:inspect).join("\n")
  end

  failure_message_when_negated do |datastore|
    failure_message.gsub("to have", "not to have")
  end
end
