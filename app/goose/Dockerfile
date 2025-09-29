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
    libxcb1 libx11-6 libxcb-xkb1 libxkbcommon-x11-0 libxss1 \
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
# Install Goose CLI non-interactively (per docs)
# https://block.github.io/goose/docs/getting-started/installation/
RUN curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh \
    | CONFIGURE=false bash
# Put CLI on PATH
RUN mv /root/.local/bin/goose /usr/local/bin/goose

########################################
# Target: Service (for Container Apps)
########################################
FROM cli AS service
# Copy configuration files
COPY default-config.yaml /root/.default-config.yaml
COPY handle-default-config.sh /usr/local/bin/handle-default-config.sh
RUN chmod +x /usr/local/bin/handle-default-config.sh

# Default command runs the Goose web UI; can be overridden at deploy time
ENTRYPOINT ["/usr/bin/tini", "--", "handle-default-config.sh", "goose"]
CMD ["web", "--host", "0.0.0.0"]