#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROXY_AUTH_PASSWORD:-}" ]; then
  read -s -p "Enter nginx proxy password: " password
  echo
  if azd env set PROXY_AUTH_PASSWORD "$password" --secret >/dev/null 2>&1; then
    :
  else
    azd env set PROXY_AUTH_PASSWORD "$password"
  fi
  export PROXY_AUTH_PASSWORD="$password"
  unset password
fi