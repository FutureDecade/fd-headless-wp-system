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

NEW_FRONTEND_IMAGE="${FRONTEND_IMAGE:-}"
NEW_WEBSOCKET_IMAGE="${WEBSOCKET_IMAGE:-}"

if [[ -z "${NEW_FRONTEND_IMAGE}" && -z "${NEW_WEBSOCKET_IMAGE}" ]]; then
  echo "Nothing to update. Pass FRONTEND_IMAGE and/or WEBSOCKET_IMAGE via environment variables."
  exit 1
fi

backup_file="${ENV_FILE}.backup-images-$(date +%Y%m%d-%H%M%S)"
cp "${ENV_FILE}" "${backup_file}"

if [[ -n "${NEW_FRONTEND_IMAGE}" ]]; then
  set_env_value "${ENV_FILE}" "FRONTEND_IMAGE" "${NEW_FRONTEND_IMAGE}"
fi

if [[ -n "${NEW_WEBSOCKET_IMAGE}" ]]; then
  set_env_value "${ENV_FILE}" "WEBSOCKET_IMAGE" "${NEW_WEBSOCKET_IMAGE}"
fi

echo "Updated runtime images."
echo "Backup: ${backup_file}"
grep -E '^(FRONTEND_IMAGE|WEBSOCKET_IMAGE)=' "${ENV_FILE}"
