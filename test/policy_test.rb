# frozen_string_literal: true

require_relative "test_helper"

class PolicyTest < Minitest::Test
  include EnvHelper

  class FakeBufferedIO
    attr_reader :io
    attr_reader :closed

    def initialize(io)
      @io = io
      @closed = false
    end

    def close
      @closed = true
    end
  end

  class FakeCert
    attr_reader :signature_algorithm

    def initialize(signature_algorithm)
      @signature_algorithm = signature_algorithm
    end
  end

  class FakeSocket
    def initialize(group, peer_cert_chain: nil)
      @group = group
      @peer_cert_chain = peer_cert_chain
    end

    def group
      @group
    end

    def peer_cert
      @peer_cert_chain&.first
    end

    def peer_cert_chain
      @peer_cert_chain
    end

    def ssl_version
      "TLSv1.3"
    end

    def cipher
      ["TLS_AES_256_GCM_SHA384"]
    end
  end

  class FakeHTTP
    attr_reader :connect_calls
    attr_reader :last_socket

    def initialize(socket)
      @socket = @last_socket = FakeBufferedIO.new(socket)
      @connect_calls = 0
    end

    def address
      "localhost"
    end

    def connect
      @connect_calls += 1
      true
    end

    private :connect
  end

  def test_allowed_group_passes
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => "pq_required",
      "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS" => "X25519MLKEM768"
    ) do
      http = Gem::PqTlsPolicy.extend_net_http_connection!(FakeHTTP.new(FakeSocket.new("X25519MLKEM768")))

      assert_equal true, http.send(:connect)
      assert_equal 1, http.connect_calls
    end
  end

  def test_disallowed_group_fails
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => "pq_required",
      "RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS" => "X25519MLKEM768"
    ) do
      http = Gem::PqTlsPolicy.extend_net_http_connection!(FakeHTTP.new(FakeSocket.new("X25519")))

      error = assert_raises(Gem::PqTlsPolicy::Violation) do
        http.send(:connect)
      end
      assert_includes error.message, "X25519"
      assert http.last_socket.closed
      assert_nil http.instance_variable_get(:@socket)
    end
  end

  def test_disabled_policy_does_not_check_group
    with_env("RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => nil) do
      http = Gem::PqTlsPolicy.extend_net_http_connection!(FakeHTTP.new(FakeSocket.new("X25519")))

      assert_equal true, http.send(:connect)
      assert_equal 1, http.connect_calls
    end
  end

  def test_extend_net_http_connection_is_idempotent
    http = FakeHTTP.new(FakeSocket.new("X25519MLKEM768"))

    assert_same http, Gem::PqTlsPolicy.extend_net_http_connection!(http)
    assert_same http, Gem::PqTlsPolicy.extend_net_http_connection!(http)
    assert http.is_a?(Gem::PqTlsPolicy::PerConnectionCheck)
  end

  def test_cert_signature_required_passes_for_allowed_leaf_signature
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY" => "pq_required",
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE" => "leaf"
    ) do
      socket = FakeSocket.new("X25519", peer_cert_chain: [FakeCert.new("ML-DSA-44")])
      http = Gem::PqTlsPolicy.extend_net_http_connection!(FakeHTTP.new(socket))

      assert_equal true, http.send(:connect)
      assert_equal 1, http.connect_calls
    end
  end

  def test_cert_signature_required_fails_for_disallowed_leaf_signature
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY" => "pq_required",
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE" => "leaf"
    ) do
      socket = FakeSocket.new("X25519", peer_cert_chain: [FakeCert.new("sha256WithRSAEncryption")])
      http = Gem::PqTlsPolicy.extend_net_http_connection!(FakeHTTP.new(socket))

      error = assert_raises(Gem::PqTlsPolicy::Violation) do
        http.send(:connect)
      end
      assert_includes error.message, "certificate signature policy violation"
      assert_includes error.message, "sha256WithRSAEncryption"
      assert http.last_socket.closed
      assert_nil http.instance_variable_get(:@socket)
    end
  end

  def test_cert_signature_observe_does_not_fail_closed
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY" => "pq_observe",
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE" => "chain_all"
    ) do
      socket = FakeSocket.new("X25519", peer_cert_chain: [FakeCert.new("sha256WithRSAEncryption")])
      http = Gem::PqTlsPolicy.extend_net_http_connection!(FakeHTTP.new(socket))

      _out, err = capture_io do
        assert_equal true, http.send(:connect)
      end

      assert_equal 1, http.connect_calls
      assert_includes err, "cert_signature_scope=chain_all"
      assert_includes err, "cert_pq=false"
    end
  end

  def test_cert_signature_required_traces_with_cert_signature_trace
    with_env(
      "RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY" => nil,
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY" => "pq_required",
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE" => "leaf",
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_TRACE" => "1"
    ) do
      socket = FakeSocket.new("X25519", peer_cert_chain: [FakeCert.new("ML-DSA-44")])
      http = Gem::PqTlsPolicy.extend_net_http_connection!(FakeHTTP.new(socket))

      _out, err = capture_io do
        assert_equal true, http.send(:connect)
      end

      assert_includes err, "cert_signature_scope=leaf"
      assert_includes err, "cert_pq=true"
    end
  end
end
