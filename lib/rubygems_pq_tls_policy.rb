# frozen_string_literal: true

require_relative "rubygems_pq_tls_policy/version"
require_relative "rubygems_pq_tls_policy/error"
require_relative "rubygems_pq_tls_policy/config"
require_relative "rubygems_pq_tls_policy/certificate_signature"
require_relative "rubygems_pq_tls_policy/patch"
require_relative "rubygems_pq_tls_policy/diagnostic"

module Gem
  module PqTlsPolicy
    class << self
      def install_if_enabled
        config = self.config
        return false unless config.enabled?

        config.validate!
        install!(config)
      end

      def install_if_enabled_for_plugin!
        install_if_enabled
      rescue Error => e
        abort "RubyGems PQ TLS policy failed to load: #{e.message} (#{e.class})"
      end

      def install!(config = self.config)
        return true if installed?

        validate_runtime!(config)
        Gem::Request::HTTPSPool.prepend(RequestHTTPSPoolPatch)
        @installed = true
        true
      end

      def installed?
        @installed == true
      end

      def warn_unavailable(message)
        warn "[rubygems:tls] #{message}" if config.trace?
      end

      def extend_net_http_connection!(http)
        http.extend(PerConnectionCheck) unless http.is_a?(PerConnectionCheck)
        http
      end

      def check_net_http_connection!(http)
        config = self.config
        return true unless config.enabled?

        config.validate!

        socket = net_http_ssl_socket(http)
        group = socket&.respond_to?(:group) ? socket.group : nil
        hostname = http.respond_to?(:address) ? http.address : "unknown"

        if config.trace?
          warn "[rubygems:tls] host=#{hostname} version=#{safe_ssl_version(socket)} cipher=#{safe_cipher_name(socket)} group=#{group.inspect}"
        end

        if config.pq_required? && !config.allowed_groups.include?(group)
          raise Gem::PqTlsPolicy::Violation,
            "RubyGems gem-server TLS key exchange policy violation: " \
            "host=#{hostname.inspect} used group=#{group.inspect}; " \
            "allowed=#{config.allowed_groups.join(',')}"
        end

        check_certificate_signature_policy!(socket, hostname, config)

        true
      end

      def validate_runtime!(config = self.config)
        begin
          require "openssl"
        rescue LoadError => e
          raise UnsupportedRuntime, "OpenSSL is unavailable: #{e.message}"
        end
        require "rubygems/request"

        requirements = []
        socket = defined?(OpenSSL::SSL::SSLSocket) ? OpenSSL::SSL::SSLSocket : nil
        https_pool = defined?(Gem::Request::HTTPSPool) ? Gem::Request::HTTPSPool : nil
        http_pool = defined?(Gem::Request::HTTPPool) ? Gem::Request::HTTPPool : nil

        requirements << "OpenSSL::SSL::SSLSocket is unavailable" unless socket
        if config.key_exchange_enabled? && !socket&.method_defined?(:group)
          requirements << "OpenSSL::SSL::SSLSocket#group is unavailable"
        end
        if config.cert_signature_enabled? &&
            !socket&.method_defined?(:peer_cert) &&
            !socket&.method_defined?(:peer_cert_chain)
          requirements << "OpenSSL::SSL::SSLSocket certificate inspection is unavailable"
        end
        requirements << "Gem::Request::HTTPSPool is unavailable" unless https_pool
        requirements << "Gem::Request::HTTPPool is unavailable" unless http_pool
        unless https_pool&.private_method_defined?(:setup_connection)
          requirements << "Gem::Request::HTTPSPool#setup_connection is unavailable"
        end
        unless http_pool&.private_method_defined?(:setup_connection)
          requirements << "Gem::Request::HTTPPool#setup_connection is unavailable"
        end

        if config.key_exchange_enabled? && !openssl_runtime_version_at_least?(3, 5, 0)
          requirements << "OpenSSL runtime must be 3.5.0 or newer for the default PQ TLS group"
        end

        return true if requirements.empty?

        message = "RubyGems PQ TLS policy cannot be enabled on this Ruby/OpenSSL runtime. " \
          "#{requirements.join('; ')}."
        if config.key_exchange_enabled?
          message += " Use Ruby linked against OpenSSL 3.5 or newer, such as ruby:4.0.5-trixie."
        end

        raise UnsupportedRuntime, message
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

      private

      def check_certificate_signature_policy!(socket, hostname, config)
        return true unless config.cert_signature_enabled?

        chain = peer_cert_chain(socket)
        verdict = Gem::PqTlsPolicy::CertificateSignature.evaluate(chain, config)

        if config.cert_signature_trace?
          warn "[rubygems:tls] host=#{hostname} cert_signature_scope=#{verdict.scope} " \
            "cert_signature_algorithms=#{verdict.algorithms.inspect} cert_pq=#{verdict.compliant?}"
        end

        if config.cert_signature_pq_required? && !verdict.compliant?
          raise Gem::PqTlsPolicy::Violation,
            "RubyGems gem-server TLS certificate signature policy violation: " \
            "host=#{hostname.inspect} scope=#{config.cert_signature_scope} " \
            "observed=#{verdict.algorithms.join(',')}; " \
            "allowed=#{config.allowed_cert_signature_algorithms.join(',')}"
        end

        true
      end

      def net_http_ssl_socket(http)
        buffered = http.instance_variable_get(:@socket)
        return buffered.io if buffered.respond_to?(:io)

        buffered
      end

      def peer_cert_chain(socket)
        chain = socket&.respond_to?(:peer_cert_chain) ? socket.peer_cert_chain : nil
        return chain unless Array(chain).empty?

        cert = socket&.respond_to?(:peer_cert) ? socket.peer_cert : nil
        cert ? [cert] : []
      rescue StandardError
        []
      end

      def safe_ssl_version(socket)
        socket&.ssl_version || "unknown"
      rescue StandardError
        "unknown"
      end

      def safe_cipher_name(socket)
        socket&.cipher&.first || "unknown"
      rescue StandardError
        "unknown"
      end
    end
  end
end
