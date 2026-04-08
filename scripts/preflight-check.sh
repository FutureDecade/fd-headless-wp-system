#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/common.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env file. Run: bash scripts/bootstrap-env.sh"
  exit 1
fi

required_commands=(
  docker
  curl
  perl
  openssl
)

for cmd in "${required_commands[@]}"; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "Missing required command: docker compose"
  exit 1
fi

required_keys=(
  FRONTEND_DOMAIN
  ADMIN_DOMAIN
  WS_DOMAIN
  FRONTEND_IMAGE
  WEBSOCKET_IMAGE
  MYSQL_DATABASE
  MYSQL_USER
  MYSQL_PASSWORD
  MYSQL_ROOT_PASSWORD
  JWT_SECRET
  PUSH_SECRET
  REVALIDATE_SECRET
)

for key in "${required_keys[@]}"; do
  if ! grep -q "^${key}=" "${ENV_FILE}"; then
    echo "Missing key in .env: ${key}"
    exit 1
  fi
done

load_env_file "${ENV_FILE}"

PUBLIC_SCHEME="${PUBLIC_SCHEME:-http}"
WEBSOCKET_PUBLIC_SCHEME="${WEBSOCKET_PUBLIC_SCHEME:-ws}"
HTTPS_ENABLED="${HTTPS_ENABLED:-false}"
WORDPRESS_FETCH_RELEASE_ASSETS="${WORDPRESS_FETCH_RELEASE_ASSETS:-false}"
WORDPRESS_RUN_INIT="${WORDPRESS_RUN_INIT:-false}"

config_errors=()

add_config_error() {
  config_errors+=("$1")
}

check_not_blank() {
  local key="$1"
  local actual="${!key:-}"

  if [[ -z "${actual}" ]]; then
    add_config_error "${key} 不能为空"
  fi
}

check_exact_placeholder() {
  local key="$1"
  local expected="$2"
  local actual="${!key:-}"

  if [[ "${actual}" == "${expected}" ]]; then
    add_config_error "${key} 还没有改，当前还是 ${expected}"
  fi
}

check_pattern_placeholder() {
  local key="$1"
  local pattern="$2"
  local actual="${!key:-}"

  if [[ "${actual}" == ${pattern} ]]; then
    add_config_error "${key} 还没有改，当前还是占位值"
  fi
}

check_allowed_value() {
  local key="$1"
  shift
  local actual="${!key:-}"
  local candidate=""

  for candidate in "$@"; do
    if [[ "${actual}" == "${candidate}" ]]; then
      return 0
    fi
  done

  add_config_error "${key} 的值无效，当前是 ${actual}"
}

check_not_blank "FRONTEND_DOMAIN"
check_not_blank "ADMIN_DOMAIN"
check_not_blank "WS_DOMAIN"
check_not_blank "FRONTEND_IMAGE"
check_not_blank "WEBSOCKET_IMAGE"
check_not_blank "MYSQL_DATABASE"
check_not_blank "MYSQL_USER"
check_not_blank "MYSQL_PASSWORD"
check_not_blank "MYSQL_ROOT_PASSWORD"
check_not_blank "JWT_SECRET"
check_not_blank "PUSH_SECRET"
check_not_blank "REVALIDATE_SECRET"

check_exact_placeholder "FRONTEND_DOMAIN" "www.example.com"
check_exact_placeholder "ADMIN_DOMAIN" "admin.example.com"
check_exact_placeholder "WS_DOMAIN" "ws.example.com"
check_pattern_placeholder "FRONTEND_IMAGE" "*CHANGE_ME*"
check_pattern_placeholder "WEBSOCKET_IMAGE" "*CHANGE_ME*"
check_pattern_placeholder "MYSQL_PASSWORD" "CHANGE_ME*"
check_pattern_placeholder "MYSQL_ROOT_PASSWORD" "CHANGE_ME*"
check_pattern_placeholder "JWT_SECRET" "CHANGE_ME*"
check_pattern_placeholder "PUSH_SECRET" "CHANGE_ME*"
check_pattern_placeholder "REVALIDATE_SECRET" "CHANGE_ME*"

check_allowed_value "PUBLIC_SCHEME" "http" "https"
check_allowed_value "WEBSOCKET_PUBLIC_SCHEME" "ws" "wss"
check_allowed_value "HTTPS_ENABLED" "true" "false"
check_allowed_value "WORDPRESS_FETCH_RELEASE_ASSETS" "true" "false"
check_allowed_value "WORDPRESS_RUN_INIT" "true" "false"

if [[ "${FRONTEND_DOMAIN:-}" == "${ADMIN_DOMAIN:-}" || "${FRONTEND_DOMAIN:-}" == "${WS_DOMAIN:-}" || "${ADMIN_DOMAIN:-}" == "${WS_DOMAIN:-}" ]]; then
  add_config_error "FRONTEND_DOMAIN、ADMIN_DOMAIN、WS_DOMAIN 不能重复"
fi

if [[ -n "${HTTP_PORT:-}" && ! "${HTTP_PORT}" =~ ^[0-9]+$ ]]; then
  add_config_error "HTTP_PORT 必须是数字，当前是 ${HTTP_PORT}"
fi

if [[ -n "${HTTPS_PORT:-}" && ! "${HTTPS_PORT}" =~ ^[0-9]+$ ]]; then
  add_config_error "HTTPS_PORT 必须是数字，当前是 ${HTTPS_PORT}"
fi

FORCE_WORDPRESS_ASSET_FETCH="${FORCE_WORDPRESS_ASSET_FETCH:-false}"
FD_THEME_RELEASE_TAG="${FD_THEME_RELEASE_TAG:-v1.0.7}"
FD_ADMIN_UI_RELEASE_TAG="${FD_ADMIN_UI_RELEASE_TAG:-v1.3.2}"
FD_MEMBER_RELEASE_TAG="${FD_MEMBER_RELEASE_TAG:-v1.0.1}"
FD_PAYMENT_RELEASE_TAG="${FD_PAYMENT_RELEASE_TAG:-v1.0.0}"
FD_COMMERCE_RELEASE_TAG="${FD_COMMERCE_RELEASE_TAG:-v1.0.0}"
FD_CONTENT_TYPES_RELEASE_TAG="${FD_CONTENT_TYPES_RELEASE_TAG:-v0.4.0}"
FD_AI_ROUTER_RELEASE_TAG="${FD_AI_ROUTER_RELEASE_TAG:-v2.2}"
FD_WEBSOCKET_PUSH_RELEASE_TAG="${FD_WEBSOCKET_PUSH_RELEASE_TAG:-v1.0.0}"
WPGRAPHQL_JWT_AUTH_RELEASE_TAG="${WPGRAPHQL_JWT_AUTH_RELEASE_TAG:-v0.7.2}"
WPGRAPHQL_TAX_QUERY_REF="${WPGRAPHQL_TAX_QUERY_REF:-v0.2.0}"

compose_files=(
  -f "${ROOT_DIR}/docker-compose.yml"
)

need_wordpress_asset_fetch() {
  if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" != "true" ]]; then
    return 1
  fi

  if [[ "${FORCE_WORDPRESS_ASSET_FETCH}" == "true" ]]; then
    return 0
  fi

  local lock_file="${ROOT_DIR}/runtime/wordpress-assets.lock"

  if [[ ! -f "${lock_file}" ]]; then
    return 0
  fi

  if [[ ! -f "${ROOT_DIR}/runtime/wp-content/themes/fd-theme/style.css" ]]; then
    return 0
  fi

  if [[ ! -f "${ROOT_DIR}/runtime/wp-content/plugins/fd-admin-ui/fd-admin-ui.php" ]]; then
    return 0
  fi

  if [[ ! -f "${ROOT_DIR}/runtime/wp-content/plugins/fd-member/index.php" ]]; then
    return 0
  fi

  if [[ ! -f "${ROOT_DIR}/runtime/wp-content/plugins/fd-payment/index.php" ]]; then
    return 0
  fi

  if [[ ! -f "${ROOT_DIR}/runtime/wp-content/plugins/fd-commerce/fd-commerce.php" ]]; then
    return 0
  fi

  if [[ ! -f "${ROOT_DIR}/runtime/wp-content/plugins/fd-content-types/fd-content-types.php" ]]; then
    return 0
  fi

  if [[ ! -f "${ROOT_DIR}/runtime/wp-content/plugins/fd-ai-router/fd-ai-router.php" ]]; then
    return 0
  fi

  if [[ ! -f "${ROOT_DIR}/runtime/wp-content/plugins/fd-websocket-push/fd-websocket-push.php" ]]; then
    return 0
  fi

  if [[ ! -f "${ROOT_DIR}/runtime/wp-content/plugins/wp-graphql-jwt-authentication/wp-graphql-jwt-authentication.php" ]]; then
    return 0
  fi

  if [[ ! -f "${ROOT_DIR}/runtime/wp-content/plugins/wp-graphql-tax-query-develop/wp-graphql-tax-query.php" ]]; then
    return 0
  fi

  local expected_lock
  expected_lock="$(cat <<EOF
fd-theme=${FD_THEME_RELEASE_TAG}
fd-admin-ui=${FD_ADMIN_UI_RELEASE_TAG}
fd-member=${FD_MEMBER_RELEASE_TAG}
fd-payment=${FD_PAYMENT_RELEASE_TAG}
fd-commerce=${FD_COMMERCE_RELEASE_TAG}
fd-content-types=${FD_CONTENT_TYPES_RELEASE_TAG}
fd-ai-router=${FD_AI_ROUTER_RELEASE_TAG}
fd-websocket-push=${FD_WEBSOCKET_PUSH_RELEASE_TAG}
wp-graphql-jwt-authentication=${WPGRAPHQL_JWT_AUTH_RELEASE_TAG}
wp-graphql-tax-query-develop=${WPGRAPHQL_TAX_QUERY_REF}
EOF
)"

  local current_lock
  current_lock="$(cat "${lock_file}")"

  if [[ "${current_lock}" != "${expected_lock}" ]]; then
    return 0
  fi

  return 1
}

if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" == "true" ]]; then
  compose_files+=(
    -f "${ROOT_DIR}/compose/wordpress-assets.override.yml"
  )

  if need_wordpress_asset_fetch; then
    for cmd in gh unzip; do
      if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "Missing required command for WordPress asset fetch: ${cmd}"
        exit 1
      fi
    done

    if [[ -z "${GH_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
      echo "GitHub CLI is not authenticated. Run: gh auth login"
      exit 1
    fi
  fi
fi

if [[ "${HTTPS_ENABLED}" == "true" ]]; then
  check_exact_placeholder "LETSENCRYPT_EMAIL" "admin@example.com"

  compose_files+=(
    -f "${ROOT_DIR}/compose/https.override.yml"
  )

  cert_dir="${ROOT_DIR}/runtime/letsencrypt/live/${FRONTEND_DOMAIN}"
  for cert_file in fullchain.pem privkey.pem; do
    if [[ ! -f "${cert_dir}/${cert_file}" ]]; then
      echo "Missing HTTPS certificate file: ${cert_dir}/${cert_file}"
      echo "Run: bash scripts/setup-https.sh"
      exit 1
    fi
  done

  if [[ "${PUBLIC_SCHEME:-http}" != "https" ]]; then
    echo "HTTPS is enabled, but PUBLIC_SCHEME is not https."
    exit 1
  fi

  if [[ "${WEBSOCKET_PUBLIC_SCHEME:-ws}" != "wss" ]]; then
    echo "HTTPS is enabled, but WEBSOCKET_PUBLIC_SCHEME is not wss."
    exit 1
  fi
fi

if [[ "${WORDPRESS_RUN_INIT}" == "true" ]]; then
  required_wp_init_keys=(
    WORDPRESS_TITLE
    WORDPRESS_ADMIN_USER
    WORDPRESS_ADMIN_PASSWORD
    WORDPRESS_ADMIN_EMAIL
  )

  for key in "${required_wp_init_keys[@]}"; do
    if [[ -z "${!key:-}" ]]; then
      echo "Missing required init setting in .env: ${key}"
      exit 1
    fi
  done

  check_pattern_placeholder "WORDPRESS_ADMIN_PASSWORD" "CHANGE_ME*"
  check_exact_placeholder "WORDPRESS_ADMIN_EMAIL" "admin@example.com"
fi

if (( ${#config_errors[@]} > 0 )); then
  echo "Preflight check failed. 请先改完这些 .env 配置："
  for error in "${config_errors[@]}"; do
    echo "- ${error}"
  done
  exit 1
fi

compose_cmd=(
  docker compose
  "${compose_files[@]}"
  --env-file "${ENV_FILE}"
)

if [[ "${WORDPRESS_RUN_INIT}" == "true" ]]; then
  compose_cmd+=(
    --profile tools
  )
fi

compose_cmd+=(
  config
)

"${compose_cmd[@]}" >/dev/null

echo "Preflight check passed."
