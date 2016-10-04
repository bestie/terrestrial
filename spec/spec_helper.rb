require "pry"
require "support/sequel_test_support"
require "support/blog_schema"

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

  config.before(backend: "memory") do
    define_singleton_method(:datastore) do
      @datastore ||= Terrestrial::MockSequel.new(BLOG_SCHEMA.fetch(:tables))
    end

    define_singleton_method(:query_counter) do
      datastore
    end
  end

  config.before(:suite) do
    Terrestrial::SequelTestSupport.drop_tables
    Terrestrial::SequelTestSupport.create_tables(BLOG_SCHEMA)
  end
end
