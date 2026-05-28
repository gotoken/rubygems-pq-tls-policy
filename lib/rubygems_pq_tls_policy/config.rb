# frozen_string_literal: true

module Gem
  module PqTlsPolicy
    class Config
      POLICY_ENV = "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY"
      TRACE_ENV = "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE"
      ALLOWED_GROUPS_ENV = "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS"
      CERT_SIGNATURE_POLICY_ENV = "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY"
      CERT_SIGNATURE_SCOPE_ENV = "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE"
      CERT_SIGNATURE_TRACE_ENV = "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_TRACE"
      ALLOWED_CERT_SIGNATURE_ALGORITHMS_ENV = "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_CERT_SIGNATURE_ALGORITHMS"

      VALID_POLICIES = [nil, "", "default", "off", "disabled", "pq_required"].freeze
      VALID_CERT_SIGNATURE_POLICIES = [nil, "", "default", "off", "disabled", "pq_observe", "pq_required"].freeze
      VALID_CERT_SIGNATURE_SCOPES = ["leaf", "chain_any", "chain_all"].freeze
      DEFAULT_ALLOWED_GROUPS = ["X25519MLKEM768"].freeze
      DEFAULT_ALLOWED_CERT_SIGNATURE_ALGORITHMS = ["ML-DSA-44", "ML-DSA-65", "ML-DSA-87"].freeze

      attr_reader :policy, :trace, :allowed_groups, :cert_signature_policy, :cert_signature_trace,
        :cert_signature_scope, :allowed_cert_signature_algorithms

      def initialize(env = ENV)
        @policy = env[POLICY_ENV]
        @trace = truthy?(env[TRACE_ENV])
        @allowed_groups = parse_groups(env[ALLOWED_GROUPS_ENV])
        @cert_signature_policy = env[CERT_SIGNATURE_POLICY_ENV]
        @cert_signature_scope = parse_cert_signature_scope(env[CERT_SIGNATURE_SCOPE_ENV])
        @cert_signature_trace = truthy?(env[CERT_SIGNATURE_TRACE_ENV])
        @allowed_cert_signature_algorithms =
          parse_cert_signature_algorithms(env[ALLOWED_CERT_SIGNATURE_ALGORITHMS_ENV])
      end

      def enabled?
        key_exchange_enabled? || cert_signature_enabled?
      end

      def key_exchange_enabled?
        !disabled_value?(policy)
      end

      def cert_signature_enabled?
        !disabled_value?(cert_signature_policy)
      end

      def pq_required?
        policy == "pq_required"
      end

      def cert_signature_pq_observe?
        cert_signature_policy == "pq_observe"
      end

      def cert_signature_pq_required?
        cert_signature_policy == "pq_required"
      end

      def trace?
        trace
      end

      def cert_signature_trace?
        cert_signature_trace || cert_signature_pq_observe?
      end

      def validate!
        unless VALID_POLICIES.include?(policy)
          raise InvalidConfiguration,
            "Unsupported #{POLICY_ENV}=#{policy.inspect}. " \
            "Supported values are: default, off, disabled, pq_required."
        end

        unless VALID_CERT_SIGNATURE_POLICIES.include?(cert_signature_policy)
          raise InvalidConfiguration,
            "Unsupported #{CERT_SIGNATURE_POLICY_ENV}=#{cert_signature_policy.inspect}. " \
            "Supported values are: default, off, disabled, pq_observe, pq_required."
        end

        return true if VALID_CERT_SIGNATURE_SCOPES.include?(cert_signature_scope)

        raise InvalidConfiguration,
          "Unsupported #{CERT_SIGNATURE_SCOPE_ENV}=#{cert_signature_scope.inspect}. " \
          "Supported values are: leaf, chain_any, chain_all."
      end

      private

      def disabled_value?(value)
        [nil, "", "default", "off", "disabled"].include?(value)
      end

      def parse_groups(value)
        groups = value.to_s.split(/[,:]/).map(&:strip).reject(&:empty?)
        groups.empty? ? DEFAULT_ALLOWED_GROUPS.dup : groups
      end

      def parse_cert_signature_scope(value)
        value.to_s.empty? ? "leaf" : value.to_s
      end

      def parse_cert_signature_algorithms(value)
        algorithms = value.to_s.split(/[,:]/).map(&:strip).reject(&:empty?)
        algorithms.empty? ? DEFAULT_ALLOWED_CERT_SIGNATURE_ALGORITHMS.dup : algorithms
      end

      def truthy?(value)
        %w[1 true yes on].include?(value.to_s.downcase)
      end
    end

    def self.config
      Config.new
    end
  end
end
