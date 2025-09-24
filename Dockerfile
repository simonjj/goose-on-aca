
# syntax=docker/dockerfile:1.7
########################################
# Base (shared)
########################################
FROM ubuntu:24.04 AS base
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    HOME=/root

# Common deps and essential tools for AI agents
# - curl, ca-certs for downloads
# - bzip2 used by Goose CLI tarball
# - tini for clean PID 1
# - git, vim, nano for development tasks
# - python3, pip for Python development
# - build-essential for compiling tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates bzip2 tini \
    git vim nano wget unzip \
    python3 python3-pip python3-venv \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

########################################
# Target: CLI
########################################
FROM base AS cli
# Install basic X11 libraries needed by Goose CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxcb1 libx11-6 libxcb-xkb1 libxkbcommon-x11-0 libxss1 \
    && rm -rf /var/lib/apt/lists/*
# Install Goose CLI non-interactively (per docs)
# https://block.github.io/goose/docs/getting-started/installation/
RUN curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh \
    | CONFIGURE=false bash
# Put CLI on PATH
RUN mv /root/.local/bin/goose /usr/local/bin/goose

# Default to a helpful entrypoint
ENTRYPOINT ["/usr/bin/tini","--","goose"]
CMD ["--help"]

########################################
# Target: Desktop (Linux)
########################################
# Uses official .deb from GitHub releases
# A few runtime libs help Electron-style apps start
# (X11/Wayland & media basics)
FROM base AS desktop
ARG GOOSE_VERSION=1.8.0
# Extra runtime libs frequently required by desktop apps
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxkbcommon0 libasound2t64 libgbm1 xdg-utils libxcb1 \
    # X11 forwarding helpers (host X must be used at runtime)
    xauth \
    && rm -rf /var/lib/apt/lists/*

# Download & install the Desktop .deb (adjust VERSION via --build-arg)
# Example asset name: goose_1.8.0_amd64.deb in the Releases page
# https://github.com/block/goose/releases (shows .deb/.rpm assets)
ADD https://github.com/block/goose/releases/download/v${GOOSE_VERSION}/goose_${GOOSE_VERSION}_amd64.deb /tmp/goose.deb
RUN apt-get update && dpkg -i /tmp/goose.deb || apt-get install -y -f \
    && rm -rf /var/lib/apt/lists/* /tmp/goose.deb

# Try to provide a stable launcher path:
# Some builds place a desktop binary called 'goose-desktop' or 'Goose'.
# Create a tiny wrapper that finds what exists.
RUN printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'for CAND in /usr/bin/goose-desktop /usr/bin/Goose /usr/local/bin/goose-desktop /opt/Goose/goose /usr/bin/goose; do' \
  '  if [ -x "$CAND" ]; then exec "$CAND" "$@"; fi' \
  'done' \
  'echo "Goose Desktop binary not found in expected locations." >&2; exit 1' \
  > /usr/local/bin/goose-desktop && chmod +x /usr/local/bin/goose-desktop

# Entry: you’ll likely run with X11 forwarding (see usage below)
ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/goose-desktop"]
CMD []
