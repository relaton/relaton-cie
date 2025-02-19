require_relative "lib/relaton/cie/version"

Gem::Specification.new do |spec|
  spec.name          = "relaton-cie"
  spec.version       = Relaton::Cie::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = <<~DESCRIPTION
    Relaton::Cie: retrieve CIE Standards for bibliographic use
    using the BibliographicItem model.
  DESCRIPTION
  spec.description = <<~DESCRIPTION
    Relaton::Cie: retrieve CIE Standards for bibliographic use
    using the BibliographicItem model.
  DESCRIPTION
  spec.homepage      = "https://github.com/metanorma/relaton-cie"
  spec.license       = "BSD-2-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["homepage_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "mechanize", "~> 2.10"
  spec.add_dependency "parslet", "~> 2.0.0"
  spec.add_dependency "relaton-bib", "~> 2.0.0-alpha.1"
  spec.add_dependency "relaton-index", "~> 0.2.0"
end
