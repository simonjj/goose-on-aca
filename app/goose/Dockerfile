# syntax=docker/dockerfile:1.7
FROM ubuntu:24.04
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
# - minimal X11 libs for Goose binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxcb1 libx11-6 \
    curl ca-certificates bzip2 tini \
    openssh-client iputils-ping \
    git vim nano wget unzip \
    python3 python3-pip python3-venv \
    build-essential \
    jq tree rsync ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages via pip with PEP 668 override
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --break-system-packages -r /tmp/requirements.txt && \
    rm -f /tmp/requirements.txt

# Install GitHub MCP server
RUN wget "https://github.com/github/github-mcp-server/releases/download/v0.17.1/github-mcp-server_Linux_x86_64.tar.gz" && \
    tar zxvf github-mcp-server_Linux_x86_64.tar.gz && \
    mv github-mcp-server /usr/local/bin/ && \
    rm github-mcp-server_Linux_x86_64.tar.gz && \
    chmod +x /usr/local/bin/github-mcp-server

WORKDIR /workspace

# Install Goose CLI non-interactively (per docs)
# https://block.github.io/goose/docs/getting-started/installation/
RUN curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh \
    | CONFIGURE=false bash
# Put CLI on PATH
RUN mv /root/.local/bin/goose /usr/local/bin/goose

# Copy configuration files
COPY default-config.yaml /root/.default-config.yaml
COPY handle-default-config.sh /usr/local/bin/handle-default-config.sh
RUN chmod +x /usr/local/bin/handle-default-config.sh

# Default command runs the Goose web UI; can be overridden at deploy time
ENTRYPOINT ["/usr/bin/tini", "--", "handle-default-config.sh", "goose"]
CMD ["web", "--host", "0.0.0.0"]