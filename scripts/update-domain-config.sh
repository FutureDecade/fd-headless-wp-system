#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/common.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env file. Run: cp .env.example .env"
  exit 1
fi

NEW_FRONTEND_DOMAIN="${FRONTEND_DOMAIN:-}"
NEW_ADMIN_DOMAIN="${ADMIN_DOMAIN:-}"
NEW_WS_DOMAIN="${WS_DOMAIN:-}"
NEW_PUBLIC_SCHEME="${PUBLIC_SCHEME:-}"
NEW_WEBSOCKET_PUBLIC_SCHEME="${WEBSOCKET_PUBLIC_SCHEME:-}"

if [[ -z "${NEW_FRONTEND_DOMAIN}" && -z "${NEW_ADMIN_DOMAIN}" && -z "${NEW_WS_DOMAIN}" && -z "${NEW_PUBLIC_SCHEME}" && -z "${NEW_WEBSOCKET_PUBLIC_SCHEME}" ]]; then
  echo "Nothing to update. Pass FRONTEND_DOMAIN, ADMIN_DOMAIN, WS_DOMAIN, PUBLIC_SCHEME and/or WEBSOCKET_PUBLIC_SCHEME via environment variables."
  exit 1
fi

backup_file="${ENV_FILE}.backup-domains-$(date +%Y%m%d-%H%M%S)"
cp "${ENV_FILE}" "${backup_file}"

if [[ -n "${NEW_FRONTEND_DOMAIN}" ]]; then
  set_env_value "${ENV_FILE}" "FRONTEND_DOMAIN" "${NEW_FRONTEND_DOMAIN}"
fi

if [[ -n "${NEW_ADMIN_DOMAIN}" ]]; then
  set_env_value "${ENV_FILE}" "ADMIN_DOMAIN" "${NEW_ADMIN_DOMAIN}"
fi

if [[ -n "${NEW_WS_DOMAIN}" ]]; then
  set_env_value "${ENV_FILE}" "WS_DOMAIN" "${NEW_WS_DOMAIN}"
fi

if [[ -n "${NEW_PUBLIC_SCHEME}" ]]; then
  set_env_value "${ENV_FILE}" "PUBLIC_SCHEME" "${NEW_PUBLIC_SCHEME}"
fi

if [[ -n "${NEW_WEBSOCKET_PUBLIC_SCHEME}" ]]; then
  set_env_value "${ENV_FILE}" "WEBSOCKET_PUBLIC_SCHEME" "${NEW_WEBSOCKET_PUBLIC_SCHEME}"
fi

echo "Updated domain settings."
echo "Backup: ${backup_file}"
grep -E '^(FRONTEND_DOMAIN|ADMIN_DOMAIN|WS_DOMAIN|PUBLIC_SCHEME|WEBSOCKET_PUBLIC_SCHEME)=' "${ENV_FILE}"
