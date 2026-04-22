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
  echo "Nothing to record. Pass FRONTEND_IMAGE and/or WEBSOCKET_IMAGE via environment variables."
  exit 1
fi

backup_file="${ENV_FILE}.backup-available-images-$(date +%Y%m%d-%H%M%S)"
cp "${ENV_FILE}" "${backup_file}"

if [[ -n "${NEW_FRONTEND_IMAGE}" ]]; then
  set_env_value "${ENV_FILE}" "AVAILABLE_FRONTEND_IMAGE" "${NEW_FRONTEND_IMAGE}"
fi

if [[ -n "${NEW_WEBSOCKET_IMAGE}" ]]; then
  set_env_value "${ENV_FILE}" "AVAILABLE_WEBSOCKET_IMAGE" "${NEW_WEBSOCKET_IMAGE}"
fi

set_env_value "${ENV_FILE}" "LAST_RUNTIME_IMAGE_OFFERED_AT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "Recorded available runtime images."
echo "Backup: ${backup_file}"
grep -E '^(AVAILABLE_FRONTEND_IMAGE|AVAILABLE_WEBSOCKET_IMAGE|LAST_RUNTIME_IMAGE_OFFERED_AT)=' "${ENV_FILE}"

ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/report-deployment-status.sh" || true
