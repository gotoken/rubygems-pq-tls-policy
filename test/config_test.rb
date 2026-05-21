# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  include EnvHelper

  def test_disabled_by_default
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS" => nil
    ) do
      config = Gem::PqTlsPolicy::Config.new
      refute config.enabled?
      refute config.trace?
      assert_equal ["X25519MLKEM768"], config.allowed_groups
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

  def test_trace_truthy_values
    %w[1 true yes on].each do |value|
      with_env("RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE" => value) do
        assert Gem::PqTlsPolicy::Config.new.trace?
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
end
