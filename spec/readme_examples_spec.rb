require "spec_helper"

require "support/object_store_setup"
require "support/seed_data_setup"
require "terrestrial"

require "spec_helper"

require "support/object_store_setup"
require "support/seed_data_setup"
require "terrestrial"

RSpec.describe "README examples", backend: "sequel" do
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
        raise e
      end
    end
  end
end
