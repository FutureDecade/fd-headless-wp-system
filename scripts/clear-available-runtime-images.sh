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

backup_file="${ENV_FILE}.backup-clear-available-runtime-$(date +%Y%m%d-%H%M%S)"
cp "${ENV_FILE}" "${backup_file}"

unset_env_keys "${ENV_FILE}" "AVAILABLE_FRONTEND_IMAGE" "AVAILABLE_WEBSOCKET_IMAGE" "LAST_RUNTIME_IMAGE_OFFERED_AT"

echo "Cleared available runtime images."
echo "Backup: ${backup_file}"
ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/report-deployment-status.sh" || true
