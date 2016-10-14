require "bundler/gem_tasks"

task :test_suite do
  puts "Run bin/test to run the entire test suite"
end

task :default => [:test_suite]

require_relative "spec/support/sequel_test_support"
require_relative "spec/support/blog_schema"

namespace :db do
  include Terrestrial::SequelTestSupport

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
