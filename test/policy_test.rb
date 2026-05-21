# frozen_string_literal: true

require_relative "test_helper"

class PolicyTest < Minitest::Test
  include EnvHelper

  class FakeSocket
    attr_reader :seen_hostname

    def initialize(group)
      @group = group
    end

    def post_connection_check(hostname)
      @seen_hostname = hostname
      true
    end

    def group
      @group
    end

    def ssl_version
      "TLSv1.3"
    end

    def cipher
      ["TLS_AES_256_GCM_SHA384"]
    end
  end

  FakeSocket.prepend(Gem::PqTlsPolicy::Patch)

  def test_allowed_group_passes
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => "pq_required",
      "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS" => "X25519MLKEM768"
    ) do
      socket = FakeSocket.new("X25519MLKEM768")
      assert_equal true, socket.post_connection_check("localhost")
    end
  end

  def test_disallowed_group_fails
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => "pq_required",
      "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS" => "X25519MLKEM768"
    ) do
      socket = FakeSocket.new("X25519")
      error = assert_raises(Gem::PqTlsPolicy::Violation) do
        socket.post_connection_check("localhost")
      end
      assert_includes error.message, "X25519"
    end
  end

  def test_disabled_policy_does_not_check_group
    with_env("RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => nil) do
      socket = FakeSocket.new("X25519")
      assert_equal true, socket.post_connection_check("localhost")
    end
  end
end
