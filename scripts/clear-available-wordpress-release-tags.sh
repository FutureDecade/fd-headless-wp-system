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

backup_file="${ENV_FILE}.backup-clear-available-tags-$(date +%Y%m%d-%H%M%S)"
cp "${ENV_FILE}" "${backup_file}"

unset_env_keys "${ENV_FILE}" \
  "AVAILABLE_FD_THEME_RELEASE_TAG" \
  "AVAILABLE_FD_PAGE_COMPOSER_RELEASE_TAG" \
  "AVAILABLE_FD_ADMIN_UI_RELEASE_TAG" \
  "AVAILABLE_FD_MEMBER_RELEASE_TAG" \
  "AVAILABLE_FD_PAYMENT_RELEASE_TAG" \
  "AVAILABLE_FD_COMMERCE_RELEASE_TAG" \
  "AVAILABLE_FD_CONTENT_TYPES_RELEASE_TAG" \
  "AVAILABLE_FD_AI_ROUTER_RELEASE_TAG" \
  "AVAILABLE_FD_WEBSOCKET_PUSH_RELEASE_TAG" \
  "AVAILABLE_WPGRAPHQL_RELEASE_TAG" \
  "AVAILABLE_WPGRAPHQL_JWT_AUTH_RELEASE_TAG" \
  "AVAILABLE_WPGRAPHQL_TAX_QUERY_REF" \
  "LAST_WORDPRESS_ASSET_UPDATE_OFFERED_AT"

echo "Cleared available WordPress asset release tags."
echo "Backup: ${backup_file}"
ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/report-deployment-status.sh" || true
