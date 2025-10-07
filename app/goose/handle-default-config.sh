#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/root/.config/goose"
CONFIG_PATH="${CONFIG_DIR}/config.yaml"
DEFAULT_CONFIG="/root/.default-config.yaml"

mkdir -p "${CONFIG_DIR}"

# Create a hash of current env vars to detect changes
CURRENT_HASH=$(echo "${MCP_EMAIL_SERVER_PASSWORD:-NA}:${GITHUB_PERSONAL_ACCESS_TOKEN:-NA}" | sha256sum | cut -d' ' -f1)
STORED_HASH_FILE="${CONFIG_DIR}/.env_hash"

if [ ! -f "${CONFIG_PATH}" ] || [ ! -f "${STORED_HASH_FILE}" ] || [ "$(cat ${STORED_HASH_FILE} 2>/dev/null || echo '')" != "${CURRENT_HASH}" ]; then
  if [ -f "${DEFAULT_CONFIG}" ]; then
    echo "Generating dynamic config from ${DEFAULT_CONFIG}..."
    cp "${DEFAULT_CONFIG}" "${CONFIG_PATH}"
    
    # Add email MCP if password is set and not "NA"
    if [ -n "${MCP_EMAIL_SERVER_PASSWORD:-}" ] && [ "${MCP_EMAIL_SERVER_PASSWORD}" != "NA" ]; then
      echo "Adding email MCP extension..."
      cat >> "${CONFIG_PATH}" << 'EOF'
  zerolib-email:
    args:
    - mcp-email-server@latest
    - stdio
    available_tools: []
    bundled: null
    cmd: uvx
    description: null
    enabled: true
    env_keys:
      - MCP_EMAIL_SERVER_EMAIL_ADDRESS
      - MCP_EMAIL_SERVER_USER_NAME
      - MCP_EMAIL_SERVER_PASSWORD
      - MCP_EMAIL_SERVER_FULL_NAME
    envs:
      MCP_EMAIL_SERVER_ACCOUNT_NAME: default
      MCP_EMAIL_SERVER_IMAP_HOST: imap.gmail.com
      MCP_EMAIL_SERVER_IMAP_PORT: '993'
      MCP_EMAIL_SERVER_SMTP_HOST: smtp.gmail.com
      MCP_EMAIL_SERVER_SMTP_SSL: 'false'
      MCP_EMAIL_SERVER_SMTP_START_SSL: 'true'
      MCP_EMAIL_SERVER_SMTP_PORT: '587'
    name: zerolib-email
    timeout: 300
    type: stdio
EOF
    fi
    
    # Add GitHub MCP if token is set and not "NA"
    if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && [ "${GITHUB_PERSONAL_ACCESS_TOKEN}" != "NA" ]; then
      echo "Adding GitHub MCP extension..."
      cat >> "${CONFIG_PATH}" << 'EOF'
  github:
    args:
    - stdio
    - --toolsets
    - repos,issues,pull_requests
    available_tools: []
    bundled: null
    cmd: github-mcp-server
    description: null
    enabled: true
    env_keys:
    - GITHUB_PERSONAL_ACCESS_TOKEN
    envs: {}
    name: Github
    timeout: 15
    type: stdio
EOF
    fi
    
    # Store the current hash
    echo "${CURRENT_HASH}" > "${STORED_HASH_FILE}"
    echo "Config generated successfully."
  else
    echo "Warning: default config ${DEFAULT_CONFIG} not found. Continuing without seeding."
  fi
else
  echo "Config up to date (environment unchanged)."
fi

exec "$@"