# frozen_string_literal: true

require_relative "test_helper"

require "openssl"

class CertificateSignatureTest < Minitest::Test
  FakeCert = Struct.new(:signature_algorithm)

  class DerOnlyCert
    def signature_algorithm
      raise "signature algorithm name unavailable"
    end

    def to_der
      tbs = OpenSSL::ASN1::Sequence([])
      algorithm = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::ObjectId("2.16.840.1.101.3.4.3.17")
      ])
      signature = OpenSSL::ASN1::BitString("")

      OpenSSL::ASN1::Sequence([tbs, algorithm, signature]).to_der
    end
  end

  def test_leaf_scope_requires_leaf_pq_signature
    config = config_for("leaf")

    verdict = Gem::PqTlsPolicy::CertificateSignature.evaluate([
      FakeCert.new("ML-DSA-44"),
      FakeCert.new("sha256WithRSAEncryption")
    ], config)

    assert verdict.compliant?
    assert_equal ["ML-DSA-44", "sha256WithRSAEncryption"], verdict.algorithms
  end

  def test_chain_any_passes_when_intermediate_is_pq
    config = config_for("chain_any")

    verdict = Gem::PqTlsPolicy::CertificateSignature.evaluate([
      FakeCert.new("sha256WithRSAEncryption"),
      FakeCert.new("ML-DSA-65")
    ], config)

    assert verdict.compliant?
  end

  def test_chain_all_requires_every_certificate_to_be_pq
    config = config_for("chain_all")

    verdict = Gem::PqTlsPolicy::CertificateSignature.evaluate([
      FakeCert.new("ML-DSA-87"),
      FakeCert.new("ecdsa-with-SHA256")
    ], config)

    refute verdict.compliant?
  end

  def test_oid_fallback_detects_mldsa_signature
    config = config_for("leaf")

    verdict = Gem::PqTlsPolicy::CertificateSignature.evaluate([DerOnlyCert.new], config)

    assert verdict.compliant?
    assert_equal ["2.16.840.1.101.3.4.3.17"], verdict.algorithms
  end

  private

  def config_for(scope)
    Gem::PqTlsPolicy::Config.new(
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY" => "pq_required",
      "RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE" => scope
    )
  end
end
