# frozen_string_literal: true

require_relative "lib/rubygems_pq_tls_policy/version"

Gem::Specification.new do |spec|
  spec.name = "rubygems-pq-tls-policy"
  spec.version = Gem::PqTlsPolicy::VERSION
  spec.authors = ["Kentaro Goto"]
  spec.email = ["gotoken@gmail.com"]

  spec.summary = "RubyGems TLS key exchange policy plugin"
  spec.description = "Checks negotiated TLS key exchange groups for RubyGems gem-server HTTPS connections."
  spec.homepage = "https://github.com/gotoken/rubygems-pq-tls-policy"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"
  spec.required_rubygems_version = ">= 4.0.0"

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "homepage_uri" => "#{spec.homepage}#readme",
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "exe/*",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt",
    "SECURITY.md"
  ]

  spec.bindir = "exe"
  spec.executables = ["rubygems-pq-tls-policy-diagnose"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "webrick", "~> 1.8"
  spec.add_development_dependency "rubygems-generate_index", "~> 1.1"
end
