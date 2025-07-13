# frozen_string_literal: true

require_relative "lib/pec_ruby/version"

Gem::Specification.new do |spec|
  spec.name = "pec_ruby"
  spec.version = PecRuby::VERSION
  spec.authors = ["EMG"]
  spec.email = ["enricomaria.giordano@icloud.com"]

  spec.summary = "Ruby gem for decoding and reading Italian PEC (Posta Elettronica Certificata) emails"
  spec.description = "A comprehensive Ruby library for handling Italian certified email (PEC) messages. Includes methods for extracting postacert.eml contents, decoding attachments, and a CLI for exploring PEC messages."
  spec.homepage = "https://github.com/egio12/pec_ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/egio12/pec_ruby"
  spec.metadata["changelog_uri"] = "https://github.com/egio12/pec_ruby/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z 2>/dev/null`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "bin"
  spec.executables = ["pec_ruby"]
  spec.require_paths = ["lib"]

  # Core dependencies
  spec.add_dependency "mail", "~> 2.7"
  spec.add_dependency "net-imap", "~> 0.3"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end