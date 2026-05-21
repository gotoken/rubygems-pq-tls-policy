# frozen_string_literal: true

require "fileutils"
require "rubygems/indexer"

ROOT = File.expand_path("../../..", __dir__)
REPO_ROOT = File.join(ROOT, "tmp", "integration", "repo")
FIXTURE_ROOT = File.join(ROOT, "tmp", "integration", "fixture")

FileUtils.rm_rf(REPO_ROOT)
FileUtils.mkdir_p(File.join(REPO_ROOT, "gems"))
FileUtils.cp(Dir[File.join(FIXTURE_ROOT, "*.gem")], File.join(REPO_ROOT, "gems"))

Gem::Indexer.new(REPO_ROOT).generate_index
puts REPO_ROOT
