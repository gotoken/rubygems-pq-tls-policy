# frozen_string_literal: true

# RubyGems can load this file by absolute path before this gem's require path is
# active. Use a relative require so plugin auto-loading works during installation.
require_relative "rubygems_pq_tls_policy"

Gem::PqTlsPolicy.install_if_enabled
