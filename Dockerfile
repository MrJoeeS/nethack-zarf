# Build NetHack from upstream source and serve it in the browser via ttyd.
ARG NETHACK_REF=NetHack-5.0

FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    bison \
    flex \
    curl \
    libncurses-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG NETHACK_REF
RUN git clone --depth 1 --branch "${NETHACK_REF}" https://github.com/NetHack/NetHack.git /src

WORKDIR /src

# Install under /opt/nethack instead of the hints file home-directory default.
RUN sed -i 's|^PREFIX=.*|PREFIX=/opt/nethack|' sys/unix/hints/linux-minimal \
    && cd sys/unix && sh setup.sh hints/linux-minimal \
    && cd /src && make fetch-lua \
    && make all \
    && make install

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libncurses6 \
    libtinfo6 \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

ARG TTYD_VERSION=1.7.7
ARG TARGETARCH
RUN case "${TARGETARCH}" in \
      amd64) TTYD_ARCH="x86_64" ;; \
      arm64) TTYD_ARCH="aarch64" ;; \
      *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && wget -qO /usr/local/bin/ttyd \
      "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}" \
    && chmod +x /usr/local/bin/ttyd

COPY --from=builder /opt/nethack /opt/nethack
COPY config/sysconf /opt/nethack/games/lib/nethackdir/sysconf
COPY config/nethackrc /var/nethack/.nethackrc
COPY entrypoint.sh /entrypoint.sh
COPY run-nethack.sh /run-nethack.sh

ENV PATH="/opt/nethack/games:${PATH}" \
    TERM=xterm-256color \
    HOME=/var/nethack

RUN groupadd -g 1000 nethack \
    && useradd -u 1000 -g 1000 -m -d /var/nethack nethack \
    && chown -R nethack:nethack /opt/nethack /var/nethack \
    && chmod +x /entrypoint.sh /run-nethack.sh

USER nethack
WORKDIR /var/nethack
EXPOSE 7681

ENTRYPOINT ["/entrypoint.sh"]
