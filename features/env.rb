require "pry"
require "sequel"
require "terrestrial"
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
      .gsub(/ \>/, ">")
      .gsub(/\:0x[0-9a-f]{14}/, ":<<object id removed>>")
  end

  def parse_schema_table(string)
    string.each_line.drop(2).map { |line|
      name, type, options = line.split("|").map(&:strip)

      {
        name: name,
        type: Object.const_get(type),
        options: string_to_schema_options(options.to_s),
      }
    }
  end

  def string_to_schema_options(string)
    Hash[
      string.split(",").map(&:strip).reject(&:empty?).map { |s|
        [s.downcase.gsub(" ", "_").to_sym, true]
      }
    ]
  end
end

module DatabaseSupport
  def create_table(name, columns)
    Terrestrial::SequelTestSupport.create_tables(
      name => columns,
    )
  end
end

Before do
  Terrestrial::SequelTestSupport.drop_tables
end

World(ExampleRunnerSupport)
World(DatabaseSupport)
