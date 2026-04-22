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

load_env_file "${ENV_FILE}"

ENV_FILE="${ENV_FILE}" \
FD_THEME_RELEASE_TAG="${AVAILABLE_FD_THEME_RELEASE_TAG:-}" \
FD_PAGE_COMPOSER_RELEASE_TAG="${AVAILABLE_FD_PAGE_COMPOSER_RELEASE_TAG:-}" \
FD_ADMIN_UI_RELEASE_TAG="${AVAILABLE_FD_ADMIN_UI_RELEASE_TAG:-}" \
FD_MEMBER_RELEASE_TAG="${AVAILABLE_FD_MEMBER_RELEASE_TAG:-}" \
FD_PAYMENT_RELEASE_TAG="${AVAILABLE_FD_PAYMENT_RELEASE_TAG:-}" \
FD_COMMERCE_RELEASE_TAG="${AVAILABLE_FD_COMMERCE_RELEASE_TAG:-}" \
FD_CONTENT_TYPES_RELEASE_TAG="${AVAILABLE_FD_CONTENT_TYPES_RELEASE_TAG:-}" \
FD_AI_ROUTER_RELEASE_TAG="${AVAILABLE_FD_AI_ROUTER_RELEASE_TAG:-}" \
FD_WEBSOCKET_PUSH_RELEASE_TAG="${AVAILABLE_FD_WEBSOCKET_PUSH_RELEASE_TAG:-}" \
WPGRAPHQL_RELEASE_TAG="${AVAILABLE_WPGRAPHQL_RELEASE_TAG:-}" \
WPGRAPHQL_JWT_AUTH_RELEASE_TAG="${AVAILABLE_WPGRAPHQL_JWT_AUTH_RELEASE_TAG:-}" \
WPGRAPHQL_TAX_QUERY_REF="${AVAILABLE_WPGRAPHQL_TAX_QUERY_REF:-}" \
bash "${ROOT_DIR}/scripts/update-wordpress-release-tags.sh"

updated=0

clear_available_tag_if_applied() {
  local current_key="$1"
  local available_key="$2"
  load_env_file "${ENV_FILE}"

  if [[ -n "${!available_key:-}" && "${!available_key}" == "${!current_key:-}" ]]; then
    unset_env_value "${ENV_FILE}" "${available_key}"
    updated=1
  fi
}

clear_available_tag_if_applied "FD_THEME_RELEASE_TAG" "AVAILABLE_FD_THEME_RELEASE_TAG"
clear_available_tag_if_applied "FD_PAGE_COMPOSER_RELEASE_TAG" "AVAILABLE_FD_PAGE_COMPOSER_RELEASE_TAG"
clear_available_tag_if_applied "FD_ADMIN_UI_RELEASE_TAG" "AVAILABLE_FD_ADMIN_UI_RELEASE_TAG"
clear_available_tag_if_applied "FD_MEMBER_RELEASE_TAG" "AVAILABLE_FD_MEMBER_RELEASE_TAG"
clear_available_tag_if_applied "FD_PAYMENT_RELEASE_TAG" "AVAILABLE_FD_PAYMENT_RELEASE_TAG"
clear_available_tag_if_applied "FD_COMMERCE_RELEASE_TAG" "AVAILABLE_FD_COMMERCE_RELEASE_TAG"
clear_available_tag_if_applied "FD_CONTENT_TYPES_RELEASE_TAG" "AVAILABLE_FD_CONTENT_TYPES_RELEASE_TAG"
clear_available_tag_if_applied "FD_AI_ROUTER_RELEASE_TAG" "AVAILABLE_FD_AI_ROUTER_RELEASE_TAG"
clear_available_tag_if_applied "FD_WEBSOCKET_PUSH_RELEASE_TAG" "AVAILABLE_FD_WEBSOCKET_PUSH_RELEASE_TAG"
clear_available_tag_if_applied "WPGRAPHQL_RELEASE_TAG" "AVAILABLE_WPGRAPHQL_RELEASE_TAG"
clear_available_tag_if_applied "WPGRAPHQL_JWT_AUTH_RELEASE_TAG" "AVAILABLE_WPGRAPHQL_JWT_AUTH_RELEASE_TAG"
clear_available_tag_if_applied "WPGRAPHQL_TAX_QUERY_REF" "AVAILABLE_WPGRAPHQL_TAX_QUERY_REF"

set_env_value "${ENV_FILE}" "LAST_WORDPRESS_ASSET_UPDATE_APPLIED_AT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "Applied available WordPress asset release tags. Run bash scripts/update-stack.sh to fetch assets and update containers."
