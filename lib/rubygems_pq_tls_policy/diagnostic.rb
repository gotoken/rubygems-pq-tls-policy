# frozen_string_literal: true

module Gem
  module PqTlsPolicy
    module Diagnostic
      module_function

      def report(io = $stdout)
        require "openssl"
        require "rubygems/request"

        io.puts "ruby=#{RUBY_DESCRIPTION}"
        io.puts "engine=#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'}"
        io.puts "openssl=#{defined?(OpenSSL::OPENSSL_VERSION) ? OpenSSL::OPENSSL_VERSION : 'unavailable'}"
        io.puts "openssl_library=#{defined?(OpenSSL::OPENSSL_LIBRARY_VERSION) ? OpenSSL::OPENSSL_LIBRARY_VERSION : 'unavailable'}"

        socket = defined?(OpenSSL::SSL::SSLSocket) ? OpenSSL::SSL::SSLSocket : nil
        context = defined?(OpenSSL::SSL::SSLContext) ? OpenSSL::SSL::SSLContext.new : nil
        https_pool = defined?(Gem::Request::HTTPSPool) ? Gem::Request::HTTPSPool : nil
        http_pool = defined?(Gem::Request::HTTPPool) ? Gem::Request::HTTPPool : nil

        io.puts "sslsocket=#{socket ? 'available' : 'unavailable'}"
        io.puts "group=#{socket&.method_defined?(:group) ? 'available' : 'unavailable'}"
        io.puts "rubygems_https_pool=#{https_pool&.private_method_defined?(:setup_connection) ? 'available' : 'unavailable'}"
        io.puts "rubygems_http_pool=#{http_pool&.private_method_defined?(:setup_connection) ? 'available' : 'unavailable'}"
        io.puts "ssl_context_groups_setter=#{context&.respond_to?(:groups=) ? 'available' : 'unavailable'}"

        policy_runtime = Gem::PqTlsPolicy.openssl_runtime_version_at_least?(3, 5, 0) &&
          socket&.method_defined?(:group) &&
          https_pool&.private_method_defined?(:setup_connection) &&
          http_pool&.private_method_defined?(:setup_connection)
        io.puts "pq_tls_policy_runtime=#{policy_runtime ? 'available' : 'unavailable'}"

        true
      rescue LoadError => e
        io.puts "openssl=unavailable"
        io.puts "error=#{e.class}: #{e.message}"
        false
      end
    end
  end
end
