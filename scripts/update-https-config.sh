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

NEW_LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
NEW_LETSENCRYPT_STAGING="${LETSENCRYPT_STAGING:-}"

if [[ -z "${NEW_LETSENCRYPT_EMAIL}" && -z "${NEW_LETSENCRYPT_STAGING}" ]]; then
  echo "Nothing to update. Pass LETSENCRYPT_EMAIL and/or LETSENCRYPT_STAGING via environment variables."
  exit 1
fi

backup_file="${ENV_FILE}.backup-https-$(date +%Y%m%d-%H%M%S)"
cp "${ENV_FILE}" "${backup_file}"

if [[ -n "${NEW_LETSENCRYPT_EMAIL}" ]]; then
  set_env_value "${ENV_FILE}" "LETSENCRYPT_EMAIL" "${NEW_LETSENCRYPT_EMAIL}"
fi

if [[ -n "${NEW_LETSENCRYPT_STAGING}" ]]; then
  set_env_value "${ENV_FILE}" "LETSENCRYPT_STAGING" "${NEW_LETSENCRYPT_STAGING}"
fi

echo "Updated HTTPS settings."
echo "Backup: ${backup_file}"
grep -E '^(LETSENCRYPT_EMAIL|LETSENCRYPT_STAGING)=' "${ENV_FILE}"
