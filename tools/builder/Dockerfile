FROM ghcr.io/lmscloudpauld/koha-builder:v1.0.0

# The base image runs as the "builder" user. Switch to root for apt
# operations, then restore at the end.
USER root
ENV DEBIAN_FRONTEND=noninteractive

# The upstream builder image ships a stale yarn apt source (expired GPG key)
# that breaks `apt-get update`. Disable it — we only need Debian main here.
RUN for f in /etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/yarn.sources; do \
        [ -f "$f" ] && mv "$f" "${f}.disabled"; \
    done || true

# Test::NoWarnings is required by the Koha test suite but missing from
# the upstream builder image. Bake it in so Phase A no longer needs to
# install at runtime (and can therefore drop --user 0:0).
RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends libtest-nowarnings-perl \
    && rm -rf /var/lib/apt/lists/*

USER builder
