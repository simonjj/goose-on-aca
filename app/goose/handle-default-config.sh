#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/root/.config/goose"
CONFIG_PATH="${CONFIG_DIR}/config.yaml"
DEFAULT_CONFIG="/root/.default-config.yaml"

mkdir -p "${CONFIG_DIR}"

if [ ! -f "${CONFIG_PATH}" ]; then
  if [ -f "${DEFAULT_CONFIG}" ]; then
    echo "No Goose config found at ${CONFIG_PATH}. Seeding default config."
    cp "${DEFAULT_CONFIG}" "${CONFIG_PATH}"
  else
    echo "Warning: default config ${DEFAULT_CONFIG} not found. Continuing without seeding."
  fi
else
  echo "Existing Goose config found at ${CONFIG_PATH}."
fi

exec "$@"