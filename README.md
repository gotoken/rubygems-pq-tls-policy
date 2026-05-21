# rubygems-pq-tls-policy

RubyGems plugin that checks the negotiated TLS key exchange group for RubyGems gem-server HTTPS connections when explicitly enabled.

This repository is an experimental starting point for testing post-quantum TLS key exchange policy enforcement around RubyGems operations.

## Scope

When enabled, this plugin installs a process-local Ruby OpenSSL hook and checks TLS connections that pass through `OpenSSL::SSL::SSLSocket#post_connection_check`.

The intended scope is RubyGems HTTPS communication with configured gem servers and gem push hosts, such as `https://rubygems.org` or a private gem server.

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
| `RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE` | `1` | Prints observed TLS version, cipher, and negotiated group. |

Default allowed group:

```text
X25519MLKEM768
```

## Example

```sh
gem install rubygems-pq-tls-policy

RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_POLICY=pq_required \
RUBYGEMS_GEM_SERVER_TLS_ALLOWED_GROUPS=X25519MLKEM768 \
RUBYGEMS_GEM_SERVER_TLS_KEY_EXCHANGE_TRACE=1 \
  gem install rake
```

A compliant connection prints trace output similar to:

```text
[rubygems:tls] host=rubygems.org version=TLSv1.3 cipher=TLS_AES_256_GCM_SHA384 group="X25519MLKEM768"
```

A non-compliant connection raises `Gem::PqTlsPolicy::Violation` before the RubyGems HTTP request proceeds.

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
- `OpenSSL::SSL::SSLContext#groups=`

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
6. restarts the server with `X25519`, and
7. verifies that non-PQ TLS group usage is rejected.

The script loads the plugin from the checkout using `RUBYOPT=-Ilib -rrubygems_plugin`, so you can test changes before packaging or installing the gem.

## Docker real-TLS integration test

If your local Ruby/OpenSSL is not suitable, use Docker:

```sh
script/integration-docker
```

This runs `script/integration` in the official `ruby:4.0.5-trixie` image, which currently provides Ruby 4.0.5 linked against OpenSSL 3.5.

To use another image:

```sh
RUBY_DOCKER_IMAGE=ruby:4.0.5-trixie script/integration-docker
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
| `PQ TLS Integration` | Builds OpenSSL 3.5+ and Ruby, then runs localhost real-TLS command tests. |

Compatibility results should be treated as observed behavior, not a compatibility guarantee.

Suggested README compatibility table after running Actions:

| Runtime | Load test | `SSLSocket#group` | Real TLS integration | Notes |
|---|---:|---:|---:|---|
| MRI + OpenSSL 3.5+ | ✅ | ✅ | ✅ | Primary target. |

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

It does not prevent a non-PQ TLS handshake from happening. It rejects the connection after observing the negotiated group.

For a stronger design, combine this plugin with client-side TLS group configuration, an internal gem mirror, or container/network-level egress policy.

## Packaging

Build the gem:

```sh
gem build rubygems-pq-tls-policy.gemspec
```

Install locally:

```sh
gem install ./rubygems-pq-tls-policy-0.1.0.gem
```

## License

MIT
