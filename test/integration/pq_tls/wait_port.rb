# frozen_string_literal: true

require "socket"

host = ARGV.fetch(0)
port = Integer(ARGV.fetch(1))
timeout = Integer(ARGV.fetch(2, "30"))
deadline = Time.now + timeout

loop do
  begin
    TCPSocket.new(host, port).close
    exit 0
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    exit 1 if Time.now >= deadline
    sleep 0.2
  end
end
