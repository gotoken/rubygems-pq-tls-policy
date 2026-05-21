# frozen_string_literal: true

require_relative "test_helper"

class IntegrationTest < Minitest::Test
  def test_local_integration_script_when_requested
    skip "Set RUN_PQ_TLS_INTEGRATION=1 to run localhost real-TLS integration" unless ENV["RUN_PQ_TLS_INTEGRATION"] == "1"

    root = File.expand_path("..", __dir__)
    assert system({ "RUN_FROM_MINITEST" => "1" }, File.join(root, "script", "integration"))
  end
end
