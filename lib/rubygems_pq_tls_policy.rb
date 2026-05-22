# frozen_string_literal: true

require_relative "rubygems_pq_tls_policy/version"
require_relative "rubygems_pq_tls_policy/error"
require_relative "rubygems_pq_tls_policy/config"
require_relative "rubygems_pq_tls_policy/patch"
require_relative "rubygems_pq_tls_policy/diagnostic"

module Gem
  module PqTlsPolicy
    class << self
      def install_if_enabled
        config = self.config
        return false unless config.enabled?

        config.validate!
        install!
      end

      def install_if_enabled_for_plugin!
        install_if_enabled
      rescue Error => e
        abort "RubyGems PQ TLS policy failed to load: #{e.message} (#{e.class})"
      end

      def install!
        return true if installed?

        validate_runtime!
        OpenSSL::SSL::SSLSocket.prepend(Patch)
        @installed = true
        true
      end

      def installed?
        @installed == true
      end

      def warn_unavailable(message)
        warn "[rubygems:tls] #{message}" if config.trace?
      end

      def validate_runtime!
        begin
          require "openssl"
        rescue LoadError => e
          raise UnsupportedRuntime, "OpenSSL is unavailable: #{e.message}"
        end

        requirements = []
        socket = defined?(OpenSSL::SSL::SSLSocket) ? OpenSSL::SSL::SSLSocket : nil

        requirements << "OpenSSL::SSL::SSLSocket is unavailable" unless socket
        unless socket&.method_defined?(:post_connection_check)
          requirements << "OpenSSL::SSL::SSLSocket#post_connection_check is unavailable"
        end
        unless socket&.method_defined?(:group)
          requirements << "OpenSSL::SSL::SSLSocket#group is unavailable"
        end

        unless openssl_runtime_version_at_least?(3, 5, 0)
          requirements << "OpenSSL runtime must be 3.5.0 or newer for the default PQ TLS group"
        end

        return true if requirements.empty?

        raise UnsupportedRuntime,
          "RubyGems PQ TLS policy cannot be enabled on this Ruby/OpenSSL runtime. " \
          "#{requirements.join('; ')}. " \
          "Use Ruby linked against OpenSSL 3.5 or newer, such as ruby:4.0.5-trixie."
      end

      def openssl_runtime_version_at_least?(major, minor, patch)
        version = if defined?(OpenSSL::OPENSSL_LIBRARY_VERSION)
          OpenSSL::OPENSSL_LIBRARY_VERSION
        elsif defined?(OpenSSL::OPENSSL_VERSION)
          OpenSSL::OPENSSL_VERSION
        end

        match = version.to_s.match(/\AOpenSSL\s+(\d+)\.(\d+)\.(\d+)/)
        return false unless match

        ([match[1].to_i, match[2].to_i, match[3].to_i] <=> [major, minor, patch]) >= 0
      end
    end
  end
end
