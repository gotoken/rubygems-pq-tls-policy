# frozen_string_literal: true

require "fileutils"

ROOT = File.expand_path("../../..", __dir__)
FIXTURE_ROOT = File.join(ROOT, "tmp", "integration", "fixture")

FileUtils.rm_rf(FIXTURE_ROOT)
FileUtils.mkdir_p(File.join(FIXTURE_ROOT, "lib"))

File.write(File.join(FIXTURE_ROOT, "lib", "pq_tls_fixture.rb"), <<~RUBY)
  # frozen_string_literal: true

  module PqTlsFixture
    VERSION = "0.1.0"
  end
RUBY

File.write(File.join(FIXTURE_ROOT, "pq_tls_fixture.gemspec"), <<~RUBY)
  # frozen_string_literal: true

  Gem::Specification.new do |s|
    s.name = "pq_tls_fixture"
    s.version = "0.1.0"
    s.summary = "PQ TLS fixture gem"
    s.authors = ["CI"]
    s.files = ["lib/pq_tls_fixture.rb"]
    s.require_paths = ["lib"]
    s.required_ruby_version = ">= 2.7"
  end
RUBY

Dir.chdir(FIXTURE_ROOT) do
  system(Gem.ruby, "-S", "gem", "build", "pq_tls_fixture.gemspec", exception: true)
end

puts File.join(FIXTURE_ROOT, "pq_tls_fixture-0.1.0.gem")
