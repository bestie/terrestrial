require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"

require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"

RSpec.describe "README examples" do
  include_context "sequel persistence setup"
  include_context "seed data setup"

  readme_contents = File.read("README.md")

  convenience_id_mappings = {
    "2f0f791c-47cf-4a00-8676-e582075bcd65" => "users/1",
    "9b75fe2b-d694-4b90-9137-6201d426dda2" => "posts/1",
    "bd564cc0-b8f1-45e6-9287-1ae75878c665" => "posts/2",
    "4af129d0-5b9f-473e-b35d-ae0125a4f79e" => "posts/3",
  }

  code_samples = readme_contents
    .split("```ruby")
    .drop(1)
    .map { |s| s.split("```").first }
    .map { |s| s.gsub(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/, convenience_id_mappings) }

  code_samples.take(1).each do |code_sample|
    it "executes" do
      File.open("./example1.rb", "w") { |f| f.puts(code_sample) }

      Module.new.module_eval(code_sample)
    end
  end
end
