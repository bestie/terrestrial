require "pry"
require "sequel"
require "logger"

`psql postgres --command "CREATE DATABASE $PGDATABASE;"`

DB = Sequel.postgres(
  host: ENV.fetch("PGHOST"),
  user: ENV.fetch("PGUSER"),
  database: ENV.fetch("PGDATABASE"),
)

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
end
