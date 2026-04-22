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

backup_file="${ENV_FILE}.backup-available-tags-$(date +%Y%m%d-%H%M%S)"
cp "${ENV_FILE}" "${backup_file}"

updated=0

record_available_tag() {
  local current_key="$1"
  local available_key="$2"
  local new_value="$3"

  if [[ -z "${new_value}" ]]; then
    return 0
  fi

  set_env_value "${ENV_FILE}" "${available_key}" "${new_value}"
  updated=1
}

record_available_tag "FD_THEME_RELEASE_TAG" "AVAILABLE_FD_THEME_RELEASE_TAG" "${FD_THEME_RELEASE_TAG:-}"
record_available_tag "FD_PAGE_COMPOSER_RELEASE_TAG" "AVAILABLE_FD_PAGE_COMPOSER_RELEASE_TAG" "${FD_PAGE_COMPOSER_RELEASE_TAG:-}"
record_available_tag "FD_ADMIN_UI_RELEASE_TAG" "AVAILABLE_FD_ADMIN_UI_RELEASE_TAG" "${FD_ADMIN_UI_RELEASE_TAG:-}"
record_available_tag "FD_MEMBER_RELEASE_TAG" "AVAILABLE_FD_MEMBER_RELEASE_TAG" "${FD_MEMBER_RELEASE_TAG:-}"
record_available_tag "FD_PAYMENT_RELEASE_TAG" "AVAILABLE_FD_PAYMENT_RELEASE_TAG" "${FD_PAYMENT_RELEASE_TAG:-}"
record_available_tag "FD_COMMERCE_RELEASE_TAG" "AVAILABLE_FD_COMMERCE_RELEASE_TAG" "${FD_COMMERCE_RELEASE_TAG:-}"
record_available_tag "FD_CONTENT_TYPES_RELEASE_TAG" "AVAILABLE_FD_CONTENT_TYPES_RELEASE_TAG" "${FD_CONTENT_TYPES_RELEASE_TAG:-}"
record_available_tag "FD_AI_ROUTER_RELEASE_TAG" "AVAILABLE_FD_AI_ROUTER_RELEASE_TAG" "${FD_AI_ROUTER_RELEASE_TAG:-}"
record_available_tag "FD_WEBSOCKET_PUSH_RELEASE_TAG" "AVAILABLE_FD_WEBSOCKET_PUSH_RELEASE_TAG" "${FD_WEBSOCKET_PUSH_RELEASE_TAG:-}"
record_available_tag "WPGRAPHQL_RELEASE_TAG" "AVAILABLE_WPGRAPHQL_RELEASE_TAG" "${WPGRAPHQL_RELEASE_TAG:-}"
record_available_tag "WPGRAPHQL_JWT_AUTH_RELEASE_TAG" "AVAILABLE_WPGRAPHQL_JWT_AUTH_RELEASE_TAG" "${WPGRAPHQL_JWT_AUTH_RELEASE_TAG:-}"
record_available_tag "WPGRAPHQL_TAX_QUERY_REF" "AVAILABLE_WPGRAPHQL_TAX_QUERY_REF" "${WPGRAPHQL_TAX_QUERY_REF:-}"

if [[ "${updated}" != "1" ]]; then
  echo "Nothing to record. Pass at least one WordPress asset release tag via environment variables."
  exit 1
fi

set_env_value "${ENV_FILE}" "LAST_WORDPRESS_ASSET_UPDATE_OFFERED_AT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "Recorded available WordPress asset release tags."
echo "Backup: ${backup_file}"
grep -E '^(AVAILABLE_(FD_(THEME|PAGE_COMPOSER|ADMIN_UI|MEMBER|PAYMENT|COMMERCE|CONTENT_TYPES|AI_ROUTER|WEBSOCKET_PUSH)_RELEASE_TAG|WPGRAPHQL_RELEASE_TAG|WPGRAPHQL_JWT_AUTH_RELEASE_TAG|WPGRAPHQL_TAX_QUERY_REF)|LAST_WORDPRESS_ASSET_UPDATE_OFFERED_AT)=' "${ENV_FILE}" || true
