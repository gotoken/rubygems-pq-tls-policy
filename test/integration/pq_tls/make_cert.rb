# frozen_string_literal: true

require "fileutils"
require "openssl"

ROOT = File.expand_path("../../..", __dir__)
CERT_DIR = File.join(ROOT, "tmp", "integration", "certs")
FileUtils.mkdir_p(CERT_DIR)

key = OpenSSL::PKey::RSA.new(2048)
cert = OpenSSL::X509::Certificate.new
cert.version = 2
cert.serial = 1
cert.subject = OpenSSL::X509::Name.parse("/CN=localhost")
cert.issuer = cert.subject
cert.public_key = key.public_key
cert.not_before = Time.now - 60
cert.not_after = Time.now + 86_400

factory = OpenSSL::X509::ExtensionFactory.new
factory.subject_certificate = cert
factory.issuer_certificate = cert
cert.add_extension(factory.create_extension("basicConstraints", "CA:FALSE", true))
cert.add_extension(factory.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
cert.add_extension(factory.create_extension("extendedKeyUsage", "serverAuth", false))
cert.add_extension(factory.create_extension("subjectAltName", "DNS:localhost,IP:127.0.0.1", false))
cert.sign(key, OpenSSL::Digest::SHA256.new)

File.write(File.join(CERT_DIR, "localhost.key"), key.to_pem)
File.write(File.join(CERT_DIR, "localhost.crt"), cert.to_pem)

puts File.join(CERT_DIR, "localhost.crt")
