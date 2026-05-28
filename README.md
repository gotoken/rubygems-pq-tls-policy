# rubygems-pq-tls-policy

RubyGems plugin that checks negotiated TLS properties for RubyGems gem-server HTTPS connections when explicitly enabled.

This repository is an experimental starting point for testing post-quantum TLS policy enforcement around RubyGems operations.

## Typical uses

Observe negotiated TLS groups:

```sh
RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE=1 \
  gem install rake
```

Require PQ TLS key exchange:

```sh
RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY=pq_required \
RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS=X25519MLKEM768 \
  gem install rake
```

Observe certificate signatures:

```sh
RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY=pq_observe \
RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE=leaf \
  gem install rake
```

Require ML-DSA certificate signatures:

```sh
RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY=pq_required \
RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE=chain_all \
  gem install rake
```

## Scope

When enabled, this plugin extends the `Gem::Net::HTTP` instances created by RubyGems' HTTPS connection pool and checks each connection after `Net::HTTP#connect` completes.

The intended scope is RubyGems HTTPS communication with configured gem servers and gem push hosts, such as `https://rubygems.org` or a private gem server.
The hook is installed on RubyGems' HTTPS pool and on the individual RubyGems HTTP connection instances it creates; it is not installed globally on `OpenSSL::SSL::SSLSocket` or `Net::HTTP`.

This is **not** a sandbox. It does **not** restrict network connections made by:

- gemspec evaluation
- native extension build scripts
- installed gems
- RubyGems or Bundler plugins
- git, ssh, curl, make, compiler toolchains, or other subprocesses
- non-Ruby OpenSSL implementations
- JRuby Java TLS internals, unless they expose the same Ruby OpenSSL behavior

For full egress control, use OS/container-level network policy.

## Configuration

The plugin is disabled by default.

```sh
RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY=pq_required \
  gem install rake
```

Supported environment variables:

| Variable | Example | Meaning |
|---|---|---|
| `RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY` | `pq_required` | Enables policy enforcement. `default`, `off`, `disabled`, or unset disables it. |
| `RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS` | `X25519MLKEM768` | Colon- or comma-separated list of allowed negotiated TLS groups. |
| `RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY` | `pq_observe` | Enables certificate signature observation or enforcement. `default`, `off`, `disabled`, or unset disables it. `pq_observe` only traces; `pq_required` rejects non-compliant chains. |
| `RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE` | `leaf` | Certificate signature check scope: `leaf`, `chain_any`, or `chain_all`. Defaults to `leaf`. |
| `RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_TRACE` | `1` | Prints certificate signature policy observations. `pq_observe` also prints these observations. |
| `RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE` | `1` | Prints observed TLS version, cipher, and negotiated group. |

Default allowed group:

```text
X25519MLKEM768
```

Default allowed certificate signature algorithms:

```text
ML-DSA-44
ML-DSA-65
ML-DSA-87
```

The ML-DSA X.509/PKIX OIDs are also recognized:

```text
2.16.840.1.101.3.4.3.17  # ML-DSA-44
2.16.840.1.101.3.4.3.18  # ML-DSA-65
2.16.840.1.101.3.4.3.19  # ML-DSA-87
```

Advanced option:

| Variable | Example | Meaning |
|---|---|---|
| `RUBYGEMS_GEM_SERVER_TLS_ALLOWED_CERT_SIGNATURE_ALGORITHMS` | `ML-DSA-44:2.16.840.1.101.3.4.3.18` | Colon- or comma-separated list of allowed certificate signature algorithm names or OIDs. This is intended for experiments with future algorithms, hybrid/composite identifiers, or vendor OIDs. |

## Example

```sh
gem install rubygems-pq-tls-policy

RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY=pq_required \
RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS=X25519MLKEM768 \
RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_POLICY=pq_observe \
RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_SCOPE=leaf \
RUBYGEMS_GEM_SERVER_TLS_CERT_SIGNATURE_TRACE=1 \
RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE=1 \
  gem install rake
```

A compliant connection prints trace output similar to:

```text
[rubygems:tls] host=rubygems.org version=TLSv1.3 cipher=TLS_AES_256_GCM_SHA384 group="X25519MLKEM768"
[rubygems:tls] host=rubygems.org cert_signature_scope=leaf cert_signature_algorithms=["ML-DSA-44"] cert_pq=true
```

A non-compliant connection raises `Gem::PqTlsPolicy::Violation` before the RubyGems HTTP request proceeds.

The certificate signature policy is independent from the TLS key exchange policy. TLS key exchange checks inspect the negotiated TLS group, while certificate signature checks inspect the X.509 chain returned by `SSLSocket#peer_cert_chain` after the handshake. `peer_cert_chain` does not include the trust anchor/root certificate.

If the policy is enabled on an unsupported runtime, the RubyGems plugin entrypoint exits the `gem` command before the requested operation runs.
This is intentional because RubyGems treats ordinary plugin load exceptions as warnings and otherwise continues.

## OpenSSL configuration

This plugin does not choose TLS groups during the handshake.
TLS negotiation is performed by Ruby's OpenSSL runtime and may be affected by system OpenSSL configuration such as `/etc/openssl/openssl.cnf` or the `OPENSSL_CONF` environment variable.

Before writing an OpenSSL configuration, check what your OpenSSL build exposes:

```sh
openssl list -tls-groups
openssl list -signature-algorithms | grep -E 'ML-DSA|SLH-DSA|RSA|ECDSA'
```

`openssl list -tls-groups` may fail on OpenSSL versions earlier than 3.5.0, where the command-line tool does not expose TLS group listing.
In that case, use `script/diagnose-tls` to check whether Ruby exposes the APIs this plugin needs.
You can also check what Ruby sees:

```sh
ruby -ropenssl -e 'p OpenSSL::OPENSSL_VERSION; p OpenSSL::OPENSSL_LIBRARY_VERSION if defined?(OpenSSL::OPENSSL_LIBRARY_VERSION); p OpenSSL::SSL::SSLContext.new.respond_to?(:groups=)'
```

For example, a local OpenSSL configuration may restrict the client groups offered by OpenSSL:

```ini
openssl_conf = openssl_init

[openssl_init]
ssl_conf = ssl_config

[ssl_config]
system_default = tls_defaults

[tls_defaults]
Groups = X25519MLKEM768
```

Then run RubyGems with that configuration and this plugin's trace enabled:

```sh
OPENSSL_CONF=/path/to/openssl.cnf \
RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE=1 \
RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY=pq_required \
RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS=X25519MLKEM768 \
  gem install rake
```

If the OpenSSL configuration prevents a usable TLS handshake, the connection can fail before this plugin has anything to inspect.
This plugin checks what was actually negotiated or presented after the handshake; it is not a replacement for client-side TLS configuration.

## Development

Install dependencies:

```sh
bundle install
```

Run unit tests:

```sh
bundle exec rake test
```

or:

```sh
script/test
```

Run a local diagnostic:

```sh
script/diagnose-tls
```

The diagnostic prints whether the current Ruby/OpenSSL exposes the APIs used by this plugin, especially:

- `OpenSSL::SSL::SSLSocket#group`
- `Gem::Request::HTTPSPool#setup_connection`
- `OpenSSL::SSL::SSLContext#groups=`

`OpenSSL::SSL::SSLContext#groups=` is used only by this plugin's development test server to force specific TLS groups during local real-TLS tests.

## Local real-TLS integration test

If your local Ruby is linked against an OpenSSL version with the required TLS group support, run:

```sh
script/integration
```

The integration script:

1. builds a fixture gem,
2. creates a static RubyGems repository,
3. generates a localhost certificate,
4. starts a localhost HTTPS gem server with `X25519MLKEM768`,
5. runs `gem fetch`, `gem install`, `bundle install`, and `gem push --host`,
6. verifies certificate signature `pq_observe` and `pq_required` behavior with classic and ML-DSA self-signed certificates,
7. restarts the server with `X25519`, and
8. verifies that non-PQ TLS group usage is rejected.

It also builds and installs this plugin into a temporary `GEM_HOME`, clears `RUBYOPT`, and verifies RubyGems plugin auto-loading from the installed gem.

The script loads the plugin from the checkout using `RUBYOPT=-Ilib -rrubygems_plugin`, so you can test changes before packaging or installing the gem.

## Docker real-TLS integration test

If your local Ruby/OpenSSL is not suitable, use Docker:

```sh
script/integration-docker
```

This runs `script/integration` in the official `ruby:4.0.5-trixie` image, which currently provides Ruby 4.0.5 linked against OpenSSL 3.5.
It also verifies that an installed plugin auto-load on `ruby:4.0.5-bookworm` fails closed before the requested `gem` operation runs.

To use another image:

```sh
RUBY_DOCKER_IMAGE=ruby:4.0.5-trixie script/integration-docker
```

To run only the certificate signature policy matrix used by GitHub Actions:

```sh
MATRIX=gha script/cert-signature-integration-docker
```

To run one certificate signature case:

```sh
CERT_SIG_CASE=pq-leaf-classic-chain \
CERT_SIG_POLICY=pq_required \
CERT_SIG_SCOPE=leaf \
CERT_SIG_EXPECT=pass \
  script/cert-signature-integration-docker
```

For an interactive shell:

```sh
script/shell-docker
```

## Docker runtime condition test

To verify the plugin's runtime checks against both supported and unsupported Ruby/OpenSSL combinations:

```sh
script/runtime-check-docker
```

By default this expects `ruby:4.0.5-trixie` to pass and `ruby:4.0.5-bookworm` to fail before installation with `Gem::PqTlsPolicy::UnsupportedRuntime`.

To use different images:

```sh
SUPPORTED_RUBY_DOCKER_IMAGE=ruby:4.0.5-trixie \
UNSUPPORTED_RUBY_DOCKER_IMAGE=ruby:4.0.5-bookworm \
  script/runtime-check-docker
```

## Docker compatibility probes

To run source-checkout probes on JRuby and TruffleRuby:

```sh
script/compatibility-docker
```

These probes load the plugin code directly from the checkout, print diagnostics, and verify that enabling the policy either installs cleanly or fails with `Gem::PqTlsPolicy::UnsupportedRuntime`.

To use different images:

```sh
JRUBY_DOCKER_IMAGE=jruby:latest \
TRUFFLERUBY_DOCKER_IMAGE=ghcr.io/flavorjones/truffleruby:latest \
  script/compatibility-docker
```

## GitHub Actions

This repository includes three workflows:

| Workflow | Purpose |
|---|---|
| `CI` | Unit tests and gem build on MRI Ruby. |
| `Compatibility` | Docker probes on JRuby and TruffleRuby. |
| `PQ TLS Integration` | Runs unit tests, localhost real-TLS command tests, certificate signature policy matrix cases, and unsupported-runtime fail-closed checks. |

Compatibility results should be treated as observed behavior, not a compatibility guarantee. Docker `latest` tags are mutable, so JRuby and TruffleRuby rows record the runtime versions observed by the compatibility probe.

Observed compatibility:

| Runtime | Policy enablement | `SSLSocket#group` | Real TLS integration | Notes |
|---|---:|---:|---:|---|
| `ruby:4.0.5-trixie` (MRI Ruby 4.0.5 + OpenSSL 3.5) | ✅ | ✅ | ✅ | Default Docker integration/runtime-check image and `PQ TLS Integration` container. |
| `ruby:4.0.5-bookworm` | ❌ | ❌ | N/A | Expected to fail with `Gem::PqTlsPolicy::UnsupportedRuntime`. |
| JRuby 10.1.0.0 (Ruby 4.0.0), JRuby-OpenSSL 0.15.6 | ❌ | ❌ | N/A | Observed by source-checkout compatibility probe on 2026-05-22. |
| TruffleRuby 24.2.2 (Ruby 3.3.7), OpenSSL 3.5.1 | ❌ | ❌ | N/A | Observed by source-checkout compatibility probe on 2026-05-22; below the gemspec Ruby requirement. |

## Command coverage

The real-TLS integration currently exercises:

| Command | Path |
|---|---|
| `gem fetch` | download/read |
| `gem install` | download/read |
| `bundle install` | Bundler resolution/install |
| `gem push --host` | upload/write |

The `gem push` test uses a local fake RubyGems-compatible HTTPS endpoint. It does not publish anything to RubyGems.org.

## Security model

This plugin checks the negotiated TLS group after TLS handshake and hostname verification, but before RubyGems continues with the HTTPS request.
When certificate signature policy is enabled, it also checks the peer certificate chain after TLS handshake and hostname verification.

It does not prevent a non-PQ TLS handshake from happening. It rejects the connection after observing the negotiated group.
Likewise, certificate signature enforcement rejects the connection only after the server certificate chain has already been received and verified by the TLS stack.

For a stronger design, combine this plugin with client-side TLS group configuration, an internal gem mirror, or container/network-level egress policy.

## Packaging

Build the gem:

```sh
gem build rubygems-pq-tls-policy.gemspec
```

Install locally:

```sh
gem install ./rubygems-pq-tls-policy-1.2.0.gem
```

## License

MIT
