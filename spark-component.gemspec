# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "spark/component/version"

Gem::Specification.new do |spec|
  spec.name          = "spark-component"
  spec.version       = Spark::Component::VERSION
  spec.authors       = ["Brandon Mathis"]
  spec.email         = ["brandon@imathis.com"]

  spec.summary       = "Add a Spark of awesome to your ActionView Component."
  spec.homepage      = "https://github.com/spark-engine/spark-component"
  spec.license       = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/spark-engine/spark-component"
  spec.metadata["changelog_uri"] = "https://github.com/spark-engine/spark-component/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "actionview-component"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "memory_profiler"
  spec.add_development_dependency "minitest", "= 5.1.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "slim"
end
