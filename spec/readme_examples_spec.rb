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

  readme_contents = File.read("README.md")

  code_samples = readme_contents
    .split("```ruby")
    .drop(1)
    .map { |s| s.split("```").first }

  code_samples.each_with_index do |code_sample, i|
    it "executes without error" do
      begin
        Module.new.module_eval(code_sample)
      rescue => e
        File.open("./example#{i}.rb", "w") { |f| f.puts(code_sample) }
        binding.pry if ENV["DEBUG"]
      end
    end
  end
end
