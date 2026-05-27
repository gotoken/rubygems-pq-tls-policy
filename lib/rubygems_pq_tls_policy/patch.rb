# frozen_string_literal: true

module Gem
  module PqTlsPolicy
    module PerConnectionCheck
      def connect
        super
        Gem::PqTlsPolicy.check_net_http_connection!(self)
      rescue Gem::PqTlsPolicy::Error
        close_pq_tls_policy_socket
        raise
      end

      private :connect

      def close_pq_tls_policy_socket
        socket = instance_variable_get(:@socket)
        socket.close if socket.respond_to?(:close)
        instance_variable_set(:@socket, nil)
      rescue StandardError
        nil
      end

      private :close_pq_tls_policy_socket
    end

    module RequestHTTPSPoolPatch
      private

      def setup_connection(connection)
        connection = Gem::Request.configure_connection_for_https(connection, @cert_files)
        Gem::PqTlsPolicy.extend_net_http_connection!(connection)
        Gem::Request::HTTPPool.instance_method(:setup_connection).bind_call(self, connection)
      end
    end
  end
end
