require "pry"
require "support/sequel_test_support"
require "support/memory_adapter_test_support"
require "support/blog_schema"

Warning[:deprecated] = false

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
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

  adapter_support = case ENV.fetch("ADAPTER", "sequel")
  when "memory"
    Terrestrial::MemoryAdapterTestSupport
  when "sequel"
    Terrestrial::SequelTestSupport
  else
    raise "Adapter `#{ENV["ADAPTER"]}` not found"
  end

  def schema
    BLOG_SCHEMA
  end

  RSpec.shared_context "adapter setup" do
    let(:datastore) { adapter_support.build_datastore(schema) }
    let(:query_counter) { adapter_support.query_counter }
  end

  config.include_context "adapter setup"

  config.before(:suite) do
    adapter_support.before_suite(schema)
  end

  config.filter_run_excluding(backend: adapter_support.excluded_adapters)
end
