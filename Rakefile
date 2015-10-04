require "bundler/gem_tasks"

require 'rspec/core/rake_task'
require 'cucumber/rake/task'

RSpec::Core::RakeTask.new
Cucumber::Rake::Task.new

task :default => [
  :spec,
  :cucumber,
]

require_relative "spec/support/sequel_test_support"
require_relative "spec/support/blog_schema"

namespace :db do
  include SequelMapper::SequelTestSupport

  task :setup => [:create] do
    create_tables(BLOG_SCHEMA)
  end

  task :create do
    create_database
  end

  task :drop do
    drop_database
  end
end
