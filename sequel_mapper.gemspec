# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sequel_mapper/version'

Gem::Specification.new do |spec|
  spec.name          = "sequel_mapper"
  spec.version       = SequelMapper::VERSION
  spec.authors       = ["Stephen Best"]
  spec.email         = ["bestie@gmail.com"]
  spec.summary       = %q{A data mapper built on top of the Sequel database toolkit}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/bestie/sequel_mapper"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "pry", "~> 0.10.1"
  spec.add_development_dependency "rspec", "~> 3.1"
  spec.add_development_dependency "pg", "~> 0.17.1"

  spec.add_dependency "sequel", "~> 4.16"
  spec.add_dependency "activesupport", "~> 4.0"
end
