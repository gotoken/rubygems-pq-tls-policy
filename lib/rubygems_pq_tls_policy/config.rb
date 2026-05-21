# frozen_string_literal: true

module Gem
  module PqTlsPolicy
    class Config
      POLICY_ENV = "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY"
      TRACE_ENV = "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE"
      ALLOWED_GROUPS_ENV = "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS"

      VALID_POLICIES = [nil, "", "default", "off", "disabled", "pq_required"].freeze
      DEFAULT_ALLOWED_GROUPS = ["X25519MLKEM768"].freeze

      attr_reader :policy, :trace, :allowed_groups

      def initialize(env = ENV)
        @policy = env[POLICY_ENV]
        @trace = truthy?(env[TRACE_ENV])
        @allowed_groups = parse_groups(env[ALLOWED_GROUPS_ENV])
      end

      def enabled?
        ![nil, "", "default", "off", "disabled"].include?(policy)
      end

      def pq_required?
        policy == "pq_required"
      end

      def trace?
        trace
      end

      def validate!
        return true if VALID_POLICIES.include?(policy)

        raise InvalidConfiguration,
          "Unsupported #{POLICY_ENV}=#{policy.inspect}. " \
          "Supported values are: default, off, disabled, pq_required."
      end

      private

      def parse_groups(value)
        groups = value.to_s.split(/[,:]/).map(&:strip).reject(&:empty?)
        groups.empty? ? DEFAULT_ALLOWED_GROUPS.dup : groups
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
