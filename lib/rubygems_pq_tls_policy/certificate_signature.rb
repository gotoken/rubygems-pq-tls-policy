# frozen_string_literal: true

module Gem
  module PqTlsPolicy
    module CertificateSignature
      ML_DSA_SIGNATURES = {
        "2.16.840.1.101.3.4.3.17" => "ML-DSA-44",
        "2.16.840.1.101.3.4.3.18" => "ML-DSA-65",
        "2.16.840.1.101.3.4.3.19" => "ML-DSA-87",
        "ML-DSA-44" => "ML-DSA-44",
        "ML-DSA-65" => "ML-DSA-65",
        "ML-DSA-87" => "ML-DSA-87"
      }.freeze

      Verdict = Struct.new(:scope, :algorithms, :compliant, keyword_init: true) do
        def compliant?
          compliant
        end
      end

      module_function

      def evaluate(chain, config)
        certs = Array(chain).compact
        results = certs.map { |cert| inspect_certificate(cert, config.allowed_cert_signature_algorithms) }
        selected_results = select_results(results, config.cert_signature_scope)

        Verdict.new(
          scope: config.cert_signature_scope,
          algorithms: results.map { |result| result[:observed] },
          compliant: compliant?(selected_results, config.cert_signature_scope)
        )
      end

      def pq_signature?(cert, allowed:)
        normalized_signature_algorithm(cert, allowed: allowed) != nil
      end

      def normalized_signature_algorithm(cert, allowed:)
        allowed = allowed.map(&:to_s)
        observed = [safe_signature_algorithm(cert), signature_oid(cert)].compact
        observed.each do |algorithm|
          normalized = ML_DSA_SIGNATURES[algorithm] || algorithm
          return normalized if allowed.include?(normalized) || allowed.include?(algorithm)
        end

        nil
      end

      def signature_oid(cert)
        asn1 = OpenSSL::ASN1.decode(cert.to_der)
        asn1.value[1].value[0].oid
      rescue StandardError
        nil
      end

      def observed_signature_algorithm(cert)
        safe_signature_algorithm(cert) || signature_oid(cert) || "unknown"
      end

      def inspect_certificate(cert, allowed)
        {
          observed: observed_signature_algorithm(cert),
          pq: pq_signature?(cert, allowed: allowed)
        }
      end
      private_class_method :inspect_certificate

      def select_results(results, scope)
        case scope
        when "leaf"
          results.first ? [results.first] : []
        when "chain_any", "chain_all"
          results
        else
          []
        end
      end
      private_class_method :select_results

      def compliant?(results, scope)
        return false if results.empty?

        case scope
        when "chain_any"
          results.any? { |result| result[:pq] }
        when "leaf", "chain_all"
          results.all? { |result| result[:pq] }
        else
          false
        end
      end
      private_class_method :compliant?

      def safe_signature_algorithm(cert)
        cert.signature_algorithm.to_s
      rescue StandardError
        nil
      end
      private_class_method :safe_signature_algorithm
    end
  end
end
