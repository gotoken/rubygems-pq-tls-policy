# frozen_string_literal: true

require "fileutils"
require "optparse"
require "openssl"
require "webrick"
require "webrick/https"

options = {
  port: 8443,
  bind: "127.0.0.1",
  pushed_path: File.expand_path("../../../tmp/integration/pushed.gem", __dir__)
}

OptionParser.new do |parser|
  parser.on("--dir DIR") { |value| options[:dir] = value }
  parser.on("--cert FILE") { |value| options[:cert] = value }
  parser.on("--key FILE") { |value| options[:key] = value }
  parser.on("--chain FILE") { |value| options[:chain] = value }
  parser.on("--port PORT", Integer) { |value| options[:port] = value }
  parser.on("--bind HOST") { |value| options[:bind] = value }
  parser.on("--groups GROUPS") { |value| options[:groups] = value }
  parser.on("--pushed-path FILE") { |value| options[:pushed_path] = value }
end.parse!

%i[dir cert key groups].each do |key|
  abort "missing --#{key.to_s.tr('_', '-')}" unless options[key]
end

cert = OpenSSL::X509::Certificate.new(File.read(options[:cert]))
key = OpenSSL::PKey.read(File.read(options[:key]))

logger = WEBrick::Log.new($stderr, WEBrick::Log::INFO)
server = WEBrick::HTTPServer.new(
  BindAddress: options[:bind],
  Port: options[:port],
  DocumentRoot: options[:dir],
  SSLEnable: true,
  SSLCertificate: cert,
  SSLPrivateKey: key,
  AccessLog: [],
  Logger: logger
)

context = server.ssl_context
context.min_version = OpenSSL::SSL::TLS1_3_VERSION if defined?(OpenSSL::SSL::TLS1_3_VERSION)
context.max_version = OpenSSL::SSL::TLS1_3_VERSION if defined?(OpenSSL::SSL::TLS1_3_VERSION)
context.extra_chain_cert = [OpenSSL::X509::Certificate.new(File.read(options[:chain]))] if options[:chain]

if context.respond_to?(:groups=)
  context.groups = options[:groups]
else
  abort "OpenSSL::SSL::SSLContext#groups= is unavailable on this Ruby/OpenSSL"
end

server.mount_proc "/api/v1/gems" do |req, res|
  unless req.request_method == "POST"
    res.status = 405
    res.body = "method not allowed"
    next
  end

  unless req.header["authorization"]&.any?
    res.status = 401
    res.body = "missing api key"
    next
  end

  FileUtils.mkdir_p(File.dirname(options[:pushed_path]))
  File.binwrite(options[:pushed_path], req.body.to_s)

  res.status = 200
  res["Content-Type"] = "text/plain"
  res.body = "Successfully registered gem"
end

# RubyGems 2.3.0's `gem push` signs in with this legacy endpoint when no
# credentials file exists. Newer RubyGems can push with GEM_HOST_API_KEY alone.
server.mount_proc "/api/v1/api_key" do |req, res|
  unless req.request_method == "GET"
    res.status = 405
    res.body = "method not allowed"
    next
  end

  res.status = 200
  res["Content-Type"] = "text/plain"
  res.body = "dummy-token"
end

trap("INT") { server.shutdown }
trap("TERM") { server.shutdown }

server.start
