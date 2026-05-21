# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "stringio"
require "rubygems_pq_tls_policy"

module EnvHelper
  def with_env(values)
    old = {}
    values.each do |key, value|
      old[key] = ENV.key?(key) ? ENV[key] : :__missing__
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    values.each_key do |key|
      if old[key] == :__missing__
        ENV.delete(key)
      else
        ENV[key] = old[key]
      end
    end
  end
end
