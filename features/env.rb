require "pry"
require "sequel"
require "sequel_mapper"
require_relative "../spec/support/sequel_test_support"

module ExampleRunnerSupport
  def example_eval_concat(code_strings)
    example_eval(code_strings.join("\n"))
  end

  def example_eval(code_string)
    example_module.module_eval(code_string)
  rescue Object => e
    binding.pry if ENV["DEBUG"]
    raise e
  end

  def example_exec(&block)
    example_exec.module_eval(&block)
  end

  def example_module
    @example_module ||= Module.new
  end

  def normalise_inspection_string(string)
    string
      .strip
      .gsub(/[\n\s]+/, " ")
      .gsub(/\:[0-9a-f]{12}/, ":<<object id removed>>")
  end

  def parse_schema_table(string)
    string.each_line.drop(2).map { |line|
      name, type = line.split("|").map(&:strip)
      {
        name: name,
        type: type,
      }
    }
  end
end

module DatabaseSupport
  def create_table(name, schema)
    SequelMapper::SequelTestSupport.create_tables(
      name => schema,
    )
  end
end

Before do
  SequelMapper::SequelTestSupport.drop_tables
end

World(ExampleRunnerSupport)
World(DatabaseSupport)
