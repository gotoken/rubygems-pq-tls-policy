# frozen_string_literal: true

module Gem
  module PqTlsPolicy
    class Error < StandardError; end
    class InvalidConfiguration < Error; end
    class UnsupportedRuntime < Error; end

    # Keep this independent from OpenSSL so simply installing the RubyGems plugin
    # does not require OpenSSL unless the policy is enabled.
    class Violation < Error; end
  end
end
