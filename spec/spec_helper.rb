require "pry-byebug"
require "support/sequel_test_support"
require "support/active_record_test_support"
require "support/memory_adapter_test_support"
require "support/blog_schema"

Warning[:deprecated] = false

File.readlines(".env").each do |line|
  _, var, value = /^export ([^=]+)="?([^"]+)"?/.match(line).to_a
  ENV[var] ||= value
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.max_formatted_output_length = 1000
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.disable_monkey_patching!

  # TODO: get everything running without warnings
  config.warnings = false

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  # config.profile_examples = 10

  # config.order = :random

  # Kernel.srand config.seed

  adapters = {
    "memory" => Terrestrial::MemoryAdapterTestSupport,
    "sequel" => Terrestrial::SequelTestSupport,
    "activerecord" => Terrestrial::ActiveRecordTestSupport,
  }

  adapter = ENV.fetch("ADAPTER", "sequel")
  adapter_support = adapters.fetch(adapter) {
    raise "Adapter not found `#{adapter}`\nMust be one of #{adapters.join(",")}."
  }

  def schema
    BLOG_SCHEMA
  end

  define_method(:adapter_support) { adapter_support }

  RSpec.shared_context "adapter setup" do
    define_method(:datastore) do
      @datastore ||= adapter_support.adapter
    end
    define_method(:db_connection) do
      @db_connection ||= adapter_support.db_connection
    end

    let(:query_counter) { adapter_support.query_counter }
  end

  config.include_context "adapter setup"

  config.before(:suite) do
    adapter_support.before_suite(schema)
  end

  config.before do
    adapter_support.before
  end

  config.after(:suite) do
    adapter_support.after_suite
  end

  # exclude tests tagged for other adapters
  other_adapters = adapters.keys - [adapter]
  config.filter_run_excluding(backend: /#{other_adapters.join("|")}/)

  config.example_status_persistence_file_path = "spec/examples.txt"
end
