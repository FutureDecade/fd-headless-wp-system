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

NEW_FD_THEME_RELEASE_TAG="${FD_THEME_RELEASE_TAG:-}"
NEW_FD_ADMIN_UI_RELEASE_TAG="${FD_ADMIN_UI_RELEASE_TAG:-}"
NEW_FD_MEMBER_RELEASE_TAG="${FD_MEMBER_RELEASE_TAG:-}"
NEW_FD_PAYMENT_RELEASE_TAG="${FD_PAYMENT_RELEASE_TAG:-}"
NEW_FD_COMMERCE_RELEASE_TAG="${FD_COMMERCE_RELEASE_TAG:-}"

if [[ -z "${NEW_FD_THEME_RELEASE_TAG}" && -z "${NEW_FD_ADMIN_UI_RELEASE_TAG}" && -z "${NEW_FD_MEMBER_RELEASE_TAG}" && -z "${NEW_FD_PAYMENT_RELEASE_TAG}" && -z "${NEW_FD_COMMERCE_RELEASE_TAG}" ]]; then
  echo "Nothing to update. Pass at least one release tag via environment variables."
  exit 1
fi

backup_file="${ENV_FILE}.backup-tags-$(date +%Y%m%d-%H%M%S)"
cp "${ENV_FILE}" "${backup_file}"

if [[ -n "${NEW_FD_THEME_RELEASE_TAG}" ]]; then
  set_env_value "${ENV_FILE}" "FD_THEME_RELEASE_TAG" "${NEW_FD_THEME_RELEASE_TAG}"
fi

if [[ -n "${NEW_FD_ADMIN_UI_RELEASE_TAG}" ]]; then
  set_env_value "${ENV_FILE}" "FD_ADMIN_UI_RELEASE_TAG" "${NEW_FD_ADMIN_UI_RELEASE_TAG}"
fi

if [[ -n "${NEW_FD_MEMBER_RELEASE_TAG}" ]]; then
  set_env_value "${ENV_FILE}" "FD_MEMBER_RELEASE_TAG" "${NEW_FD_MEMBER_RELEASE_TAG}"
fi

if [[ -n "${NEW_FD_PAYMENT_RELEASE_TAG}" ]]; then
  set_env_value "${ENV_FILE}" "FD_PAYMENT_RELEASE_TAG" "${NEW_FD_PAYMENT_RELEASE_TAG}"
fi

if [[ -n "${NEW_FD_COMMERCE_RELEASE_TAG}" ]]; then
  set_env_value "${ENV_FILE}" "FD_COMMERCE_RELEASE_TAG" "${NEW_FD_COMMERCE_RELEASE_TAG}"
fi

echo "Updated WordPress asset release tags."
echo "Backup: ${backup_file}"
grep -E '^FD_(THEME|ADMIN_UI|MEMBER|PAYMENT|COMMERCE)_RELEASE_TAG=' "${ENV_FILE}"
