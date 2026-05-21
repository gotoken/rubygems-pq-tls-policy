# Security Policy

Please report security issues privately to the maintainers before public disclosure.

## Scope

This gem is a RubyGems plugin that checks negotiated TLS key exchange groups for RubyGems gem-server HTTPS connections when explicitly enabled.

It is not a sandbox. It does not restrict network connections made by installed gems, gemspec evaluation, native extension build scripts, RubyGems/Bundler plugins, git, ssh, curl, or other subprocesses.
