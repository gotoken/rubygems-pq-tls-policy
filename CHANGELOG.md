# Changelog

## Unreleased

## 0.2.0 - 2026-05-22

- Run the PQ TLS integration workflow in the `ruby:4.0.5-trixie` container instead of building Ruby and OpenSSL from source.
- Add push-triggered PQ TLS integration runs for relevant source, script, workflow, and gemspec changes.
- Update GitHub Actions to Node.js 24-compatible action versions.
- Document observed compatibility results for MRI, JRuby, and TruffleRuby runtimes.
- Clarify that the process-local OpenSSL hook can affect other Ruby OpenSSL HTTPS connections in the same Ruby process.
- Clarify that `OpenSSL::SSL::SSLContext#groups=` is used only by the development real-TLS test server.

## 0.1.0 - 2026-05-22

- Initial repository skeleton.
- RubyGems plugin gated by environment variables.
- Local and GitHub Actions integration-test scaffolding for PQ TLS group checks.
