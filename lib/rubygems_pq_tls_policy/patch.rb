# frozen_string_literal: true

module Gem
  module PqTlsPolicy
    module Patch
      def post_connection_check(hostname)
        result = super

        config = Gem::PqTlsPolicy.config
        return result unless config.enabled?

        config.validate!

        group = respond_to?(:group) ? self.group : nil

        if config.trace?
          warn "[rubygems:tls] host=#{hostname} version=#{safe_ssl_version} cipher=#{safe_cipher_name} group=#{group.inspect}"
        end

        if config.pq_required? && !config.allowed_groups.include?(group)
          raise Gem::PqTlsPolicy::Violation,
            "RubyGems gem-server TLS key exchange policy violation: " \
            "host=#{hostname.inspect} used group=#{group.inspect}; " \
            "allowed=#{config.allowed_groups.join(',')}"
        end

        result
      end

      private

      def safe_ssl_version
        ssl_version
      rescue StandardError
        "unknown"
      end

      def safe_cipher_name
        cipher&.first
      rescue StandardError
        "unknown"
      end
    end
  end
end
