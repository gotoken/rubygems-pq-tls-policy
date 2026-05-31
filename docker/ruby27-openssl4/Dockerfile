# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=debian:trixie
FROM ${BASE_IMAGE}

ARG RUBY_VERSION=2.7.8
ARG OPENSSL_GEM_VERSION=4.0.0
ARG RUBYGEMS_VERSION=2.3.0
ARG BUNDLER_VERSION=1.17.3

ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      autoconf \
      bison \
      build-essential \
      ca-certificates \
      curl \
      libdb-dev \
      libffi-dev \
      libgdbm-dev \
      libncurses-dev \
      libreadline-dev \
      libssl-dev \
      libyaml-dev \
      make \
      xz-utils \
      zlib1g-dev

RUN openssl version

RUN mkdir -p /tmp/ruby-build && \
    cd /tmp/ruby-build && \
    curl -fsSLO "https://cache.ruby-lang.org/pub/ruby/2.7/ruby-${RUBY_VERSION}.tar.xz" && \
    tar -xf "ruby-${RUBY_VERSION}.tar.xz" && \
    cd "ruby-${RUBY_VERSION}" && \
    ./configure \
      --prefix="/opt/ruby-${RUBY_VERSION}" \
      --disable-install-doc \
      --with-out-ext=openssl,-test- \
      optflags="-O2" && \
    make -j"$(nproc)" && \
    make install || \
      test -x "/opt/ruby-${RUBY_VERSION}/bin/ruby"

ENV PATH="/opt/ruby-${RUBY_VERSION}/bin:${PATH}"
RUN ruby -v && \
    ruby -e 'begin; require "openssl"; abort "unexpected bundled OpenSSL extension"; rescue LoadError; puts "bundled OpenSSL extension is absent"; end'

RUN mkdir -p "/opt/ruby-openssl-${OPENSSL_GEM_VERSION}" && \
    curl -fsSL "https://github.com/ruby/openssl/archive/refs/tags/v${OPENSSL_GEM_VERSION}.tar.gz" | \
      tar -xz -C "/opt/ruby-openssl-${OPENSSL_GEM_VERSION}" --strip-components=1 && \
    cd "/opt/ruby-openssl-${OPENSSL_GEM_VERSION}/ext/openssl" && \
    ruby extconf.rb --with-openssl-dir=/usr && \
    make -j"$(nproc)"

ENV RUBYLIB="/opt/ruby-openssl-${OPENSSL_GEM_VERSION}/lib:/opt/ruby-openssl-${OPENSSL_GEM_VERSION}/ext/openssl"
ENV RUBY27_OPENSSL4_OPENSSL_GEM_VERSION="${OPENSSL_GEM_VERSION}"
ENV RUBY27_OPENSSL4_RUBYGEMS_VERSION="${RUBYGEMS_VERSION}"
ENV RUBY27_OPENSSL4_BUNDLER_VERSION="${BUNDLER_VERSION}"

RUN ruby -ropenssl -e ' \
      puts OpenSSL::OPENSSL_LIBRARY_VERSION; \
      expected = ENV.fetch("RUBY27_OPENSSL4_OPENSSL_GEM_VERSION"); \
      abort "expected openssl gem #{expected}, got #{OpenSSL::VERSION}" unless OpenSSL::VERSION == expected; \
      abort "expected OpenSSL 3.5.x runtime" unless OpenSSL::OPENSSL_LIBRARY_VERSION.start_with?("OpenSSL 3.5."); \
      abort "expected SSLSocket#group" unless OpenSSL::SSL::SSLSocket.method_defined?(:group); \
    '

RUN gem install openssl -v "${OPENSSL_GEM_VERSION}" --no-document && \
    ruby -ropenssl -e 'abort "expected openssl gem #{ENV.fetch("RUBY27_OPENSSL4_OPENSSL_GEM_VERSION")}, got #{OpenSSL::VERSION}" unless OpenSSL::VERSION == ENV.fetch("RUBY27_OPENSSL4_OPENSSL_GEM_VERSION")'

RUN gem install rubygems-update -v "${RUBYGEMS_VERSION}" --no-document && \
    update_rubygems && \
    gem --version | grep -x "${RUBYGEMS_VERSION}"

RUN gem install bundler -v "${BUNDLER_VERSION}" --no-ri --no-rdoc && \
    gem install minitest -v 5.26.1 --no-ri --no-rdoc && \
    gem install rake -v "~> 13.0" --no-ri --no-rdoc && \
    gem install builder -v "~> 3.2" --no-ri --no-rdoc && \
    gem install webrick -v "~> 1.8" --no-ri --no-rdoc && \
    ruby -e 'abort "unexpected RubyGems #{Gem::VERSION}" unless Gem::VERSION == ENV.fetch("RUBY27_OPENSSL4_RUBYGEMS_VERSION")' && \
    ruby -S bundle --version
