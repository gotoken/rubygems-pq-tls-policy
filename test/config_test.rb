# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  include EnvHelper

  def test_disabled_by_default
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_TRACE" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_CERT_SIGNATURE_ALGORITHMS" => nil
    ) do
      config = Gem::PqTlsPolicy::Config.new
      refute config.enabled?
      refute config.trace?
      refute config.cert_signature_trace?
      assert_equal ["X25519MLKEM768"], config.allowed_groups
      assert_equal "leaf", config.cert_signature_scope
      assert_equal ["ML-DSA-44", "ML-DSA-65", "ML-DSA-87"], config.allowed_cert_signature_algorithms
    end
  end

  def test_pq_required_enabled
    with_env("RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => "pq_required") do
      config = Gem::PqTlsPolicy::Config.new
      assert config.enabled?
      assert config.pq_required?
      assert config.validate!
    end
  end

  def test_allowed_groups_parse_colon_and_comma
    with_env("RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS" => "X25519MLKEM768:SecP256r1MLKEM768,SecP384r1MLKEM1024") do
      config = Gem::PqTlsPolicy::Config.new
      assert_equal ["X25519MLKEM768", "SecP256r1MLKEM768", "SecP384r1MLKEM1024"], config.allowed_groups
    end
  end

  def test_cert_signature_observe_enabled
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY" => "pq_observe",
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE" => "chain_any",
      "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_CERT_SIGNATURE_ALGORITHMS" => "ML-DSA-44:2.16.840.1.101.3.4.3.18"
    ) do
      config = Gem::PqTlsPolicy::Config.new
      assert config.enabled?
      refute config.key_exchange_enabled?
      assert config.cert_signature_enabled?
      assert config.cert_signature_pq_observe?
      assert config.cert_signature_trace?
      assert_equal "chain_any", config.cert_signature_scope
      assert_equal ["ML-DSA-44", "2.16.840.1.101.3.4.3.18"], config.allowed_cert_signature_algorithms
      assert config.validate!
    end
  end

  def test_trace_truthy_values
    %w[1 true yes on].each do |value|
      with_env("RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE" => value) do
        assert Gem::PqTlsPolicy::Config.new.trace?
      end
      with_env("RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_TRACE" => value) do
        assert Gem::PqTlsPolicy::Config.new.cert_signature_trace?
      end
    end
  end

  def test_unknown_policy_is_invalid
    with_env("RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => "pqc_only") do
      assert_raises(Gem::PqTlsPolicy::InvalidConfiguration) do
        Gem::PqTlsPolicy::Config.new.validate!
      end
    end
  end

  def test_unknown_cert_signature_policy_is_invalid
    with_env("RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY" => "pqc_only") do
      assert_raises(Gem::PqTlsPolicy::InvalidConfiguration) do
        Gem::PqTlsPolicy::Config.new.validate!
      end
    end
  end

  def test_unknown_cert_signature_scope_is_invalid
    with_env("RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE" => "whole_tree") do
      assert_raises(Gem::PqTlsPolicy::InvalidConfiguration) do
        Gem::PqTlsPolicy::Config.new.validate!
      end
    end
  end
end
