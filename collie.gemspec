# frozen_string_literal: true

require_relative "lib/collie/version"

Gem::Specification.new do |spec|
  spec.name = "collie"
  spec.version = Collie::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "A linter and formatter for Lrama Style BNF grammar files"
  spec.description = "Collie is a linter and formatter for Lrama Style BNF grammar files (.y files). " \
                     "It helps establish best practices for grammar file development and improves " \
                     "maintainability of complex parsers."
  spec.homepage = "https://github.com/ydah/collie"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "pastel", "~> 0.8"
  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "tty-table", "~> 0.12"
end
