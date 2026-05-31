# frozen_string_literal: true

require "yaml"
require "rubygems/specification"
require "rubygems/remote_fetcher"

if Gem::VERSION == "2.3.0" && defined?(Psych)
  # RubyGems 2.3.0's `gem push` checks rubygems.org for the latest
  # RubyGems version before uploading. This probe should stay local.
  def Gem.latest_rubygems_version
    Gem.rubygems_version
  end

  class Gem::RemoteFetcher
    # RubyGems 2.3.0 tries a DNS SRV lookup for `_rubygems._tcp.<host>`
    # before each remote request. For the local 127.0.0.1 test server this can
    # wait on DNS timeout, so skip endpoint discovery in this probe.
    def api_endpoint(uri)
      uri
    end
  end

  class Gem::Specification
    # RubyGems 2.3.0 can take the old `YAML.quick_emit` path when building
    # gems under Ruby 2.7, but modern Psych no longer provides that API.
    # Force the Psych emitter path so `gem build` works in this probe.
    def to_yaml(_opts = {})
      require "rubygems/psych_tree" unless Gem.const_defined?(:NoAliasYAMLTree)

      builder = Gem::NoAliasYAMLTree.create
      builder << self
      ast = builder.tree

      io = Gem::StringSink.new
      io.set_encoding Encoding::UTF_8 if Object.const_defined?(:Encoding)

      Psych::Visitors::Emitter.new(io).accept(ast)

      io.string.gsub(/ !!null \n/, " \n")
    end
  end
end
