# frozen_string_literal: true

require_relative "test_helper"

class PatchLoadTest < Minitest::Test
  include EnvHelper

  def test_install_if_enabled_returns_false_when_disabled
    with_env("RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => nil) do
      refute Gem::PqTlsPolicy.install_if_enabled
    end
  end

  def test_diagnostic_runs
    output = StringIO.new
    assert Gem::PqTlsPolicy::Diagnostic.report(output)
    assert_includes output.string, "ruby="
  rescue LoadError
    skip "OpenSSL unavailable on this runtime"
  end

  def test_enabled_policy_fails_early_on_unsupported_runtime
    require "openssl"

    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => "pq_required",
      "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS" => "X25519MLKEM768"
    ) do
      skip "runtime supports PQ TLS policy" if Gem::PqTlsPolicy.openssl_runtime_version_at_least?(3, 5, 0) &&
        OpenSSL::SSL::SSLSocket.method_defined?(:group)

      error = assert_raises(Gem::PqTlsPolicy::UnsupportedRuntime) do
        Gem::PqTlsPolicy.install_if_enabled
      end

      assert_includes error.message, "RubyGems PQ TLS policy cannot be enabled"
      assert_includes error.message, "OpenSSL"
    end
  rescue LoadError
    skip "OpenSSL unavailable on this runtime"
  end
end
