FROM alpine:3.5
MAINTAINER HandcraftedBits <opensource@handcraftedbits.com>

COPY data /

HEALTHCHECK --interval=2s --timeout=1s --retries=15 CMD test -f /tmp/unitStarted