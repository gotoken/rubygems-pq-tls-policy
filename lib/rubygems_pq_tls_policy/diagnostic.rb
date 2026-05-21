# frozen_string_literal: true

module Gem
  module PqTlsPolicy
    module Diagnostic
      module_function

      def report(io = $stdout)
        require "openssl"

        io.puts "ruby=#{RUBY_DESCRIPTION}"
        io.puts "engine=#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'}"
        io.puts "openssl=#{defined?(OpenSSL::OPENSSL_VERSION) ? OpenSSL::OPENSSL_VERSION : 'unavailable'}"
        io.puts "openssl_library=#{defined?(OpenSSL::OPENSSL_LIBRARY_VERSION) ? OpenSSL::OPENSSL_LIBRARY_VERSION : 'unavailable'}"

        socket = defined?(OpenSSL::SSL::SSLSocket) ? OpenSSL::SSL::SSLSocket : nil
        context = defined?(OpenSSL::SSL::SSLContext) ? OpenSSL::SSL::SSLContext.new : nil

        io.puts "sslsocket=#{socket ? 'available' : 'unavailable'}"
        io.puts "post_connection_check=#{socket&.method_defined?(:post_connection_check) ? 'available' : 'unavailable'}"
        io.puts "group=#{socket&.method_defined?(:group) ? 'available' : 'unavailable'}"
        io.puts "ssl_context_groups_setter=#{context&.respond_to?(:groups=) ? 'available' : 'unavailable'}"
        io.puts "pq_tls_policy_runtime=#{Gem::PqTlsPolicy.openssl_runtime_version_at_least?(3, 5, 0) && socket&.method_defined?(:group) ? 'available' : 'unavailable'}"

        true
      rescue LoadError => e
        io.puts "openssl=unavailable"
        io.puts "error=#{e.class}: #{e.message}"
        false
      end
    end
  end
end
