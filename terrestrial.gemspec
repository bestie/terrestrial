# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'terrestrial/version'

Gem::Specification.new do |spec|
  spec.name          = "terrestrial"
  spec.version       = Terrestrial::VERSION
  spec.authors       = ["Stephen Best"]
  spec.email         = ["bestie@gmail.com"]
  spec.summary       = %q{A data mapper ORM for Ruby}
  spec.description   = %q{A data mapper ORM for Ruby. Persists POROs, enables DDD and fast tests. Makes your objects less alien.}
  spec.homepage      = "https://github.com/bestie/terrestrial"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "pry", "~> 0.13"
  spec.add_development_dependency "rspec", "~> 3.9"
  spec.add_development_dependency "cucumber", "~> 3.1"
  spec.add_development_dependency "pg", "~> 1.0"

  spec.add_dependency "sequel", "~> 5.0"
  spec.add_dependency "fetchable", "~> 1.0"
end
