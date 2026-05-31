# Changelog

## Unreleased

## 2.0.0 - 2026-05-31

- Lower gem install requirements to Ruby 2.7 or newer and RubyGems 2.3.0 or newer.
- Add an `openssl` gem 4.0.x runtime dependency while keeping OpenSSL library capability checks at runtime.
- Add a Docker compatibility probe for Ruby 2.7.8, RubyGems 2.3.0, `openssl` gem 4.0.0, and Debian trixie's OpenSSL 3.5 runtime.
- Update the real-TLS integration helpers for RubyGems 2.3.0 behavior, including legacy `gem push` sign-in support.
- Document the split between gem install metadata requirements and runtime OpenSSL capability checks.

## 1.2.0 - 2026-05-29

- Add an independent certificate signature policy for RubyGems HTTPS connections.
- Add `RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY` with `pq_observe` and `pq_required` modes.
- Add `RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE` for `leaf`, `chain_any`, and `chain_all` checks.
- Add `RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_TRACE` for certificate signature observations.
- Recognize ML-DSA-44, ML-DSA-65, and ML-DSA-87 certificate signatures by name and X.509 OID.
- Add an advanced `RUBYGEMS_GEM_SERVER_TLS_ALLOWED_CERT_SIGNATURE_ALGORITHMS` allowlist.
- Add Docker and GitHub Actions coverage for classic and ML-DSA certificate signature policy cases.
- Document typical use cases for observing and enforcing PQ TLS key exchange and certificate signatures.

## 1.1.0 - 2026-05-28

- Limit policy installation to RubyGems HTTPS connection pools and per-connection `Gem::Net::HTTP#connect` checks instead of globally prepending `OpenSSL::SSL::SSLSocket`.

## 1.0.1 - 2026-05-22

- Make RubyGems plugin load failures terminate the `gem` command when the PQ TLS policy is enabled but cannot be installed.
- Add integration coverage for RubyGems plugin auto-loading from an installed gem on supported and unsupported Docker runtimes.

## 1.0.0 - 2026-05-22

- Run the PQ TLS integration workflow in the `ruby:4.0.5-trixie` container instead of building Ruby and OpenSSL from source.
- Add push-triggered PQ TLS integration runs for relevant source, script, workflow, and gemspec changes.
- Update GitHub Actions to Node.js 24-compatible action versions.
- Add GitHub Actions release publishing through RubyGems.org Trusted Publishing.
- Document observed compatibility results for MRI, JRuby, and TruffleRuby runtimes.
- Clarify that the process-local OpenSSL hook can affect other Ruby OpenSSL HTTPS connections in the same Ruby process.
- Clarify that `OpenSSL::SSL::SSLContext#groups=` is used only by the development real-TLS test server.

## 0.1.0 - 2026-05-22

- Initial repository skeleton.
- RubyGems plugin gated by environment variables.
- Local and GitHub Actions integration-test scaffolding for PQ TLS group checks.
