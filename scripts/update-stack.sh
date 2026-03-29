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

ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/preflight-check.sh"
load_env_file "${ENV_FILE}"

WORDPRESS_FETCH_RELEASE_ASSETS="${WORDPRESS_FETCH_RELEASE_ASSETS:-false}"
WORDPRESS_RUN_INIT="${WORDPRESS_RUN_INIT:-false}"
ACR_USERNAME="${ACR_USERNAME:-}"
ACR_PASSWORD="${ACR_PASSWORD:-}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_ENABLED="${HTTPS_ENABLED:-false}"
HTTPS_PORT="${HTTPS_PORT:-443}"

compose_files=(
  -f "${ROOT_DIR}/docker-compose.yml"
)

if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" == "true" ]]; then
  compose_files+=(
    -f "${ROOT_DIR}/compose/wordpress-assets.override.yml"
  )
fi

if [[ "${HTTPS_ENABLED}" == "true" ]]; then
  compose_files+=(
    -f "${ROOT_DIR}/compose/https.override.yml"
  )
fi

compose_base=(
  docker compose
  "${compose_files[@]}"
  --env-file "${ENV_FILE}"
)

compose_tools=(
  docker compose
  "${compose_files[@]}"
  --profile tools
  --env-file "${ENV_FILE}"
)

desired_assets_lock() {
  cat <<EOF
fd-theme=${FD_THEME_RELEASE_TAG:-v1.0.0}
fd-admin-ui=${FD_ADMIN_UI_RELEASE_TAG:-v1.3.1}
fd-member=${FD_MEMBER_RELEASE_TAG:-v1.0.1}
fd-payment=${FD_PAYMENT_RELEASE_TAG:-v1.0.0}
fd-commerce=${FD_COMMERCE_RELEASE_TAG:-v1.0.0}
fd-content-types=${FD_CONTENT_TYPES_RELEASE_TAG:-v0.1.0}
fd-websocket-push=${FD_WEBSOCKET_PUSH_RELEASE_TAG:-v1.0.0}
wp-graphql-jwt-authentication=${WPGRAPHQL_JWT_AUTH_RELEASE_TAG:-v0.7.2}
wp-graphql-tax-query-develop=${WPGRAPHQL_TAX_QUERY_REF:-v0.2.0}
EOF
}

need_wordpress_asset_sync() {
  if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" != "true" ]]; then
    return 1
  fi

  local lock_file="${ROOT_DIR}/runtime/wordpress-assets.lock"

  if [[ ! -f "${lock_file}" ]]; then
    return 0
  fi

  local current_lock
  current_lock="$(cat "${lock_file}")"

  if [[ "${current_lock}" != "$(desired_assets_lock)" ]]; then
    return 0
  fi

  return 1
}

detect_registry_host() {
  local image="$1"

  if [[ "${image}" != */* ]]; then
    return 1
  fi

  local first_segment="${image%%/*}"
  if [[ "${first_segment}" == *.* || "${first_segment}" == *:* || "${first_segment}" == "localhost" ]]; then
    printf '%s\n' "${first_segment}"
    return 0
  fi

  return 1
}

login_acr_if_needed() {
  local registry=""
  local image=""
  local -a seen=()

  for image in \
    "${MARIADB_IMAGE:-}" \
    "${REDIS_IMAGE:-}" \
    "${WORDPRESS_IMAGE:-}" \
    "${FRONTEND_IMAGE:-}" \
    "${WEBSOCKET_IMAGE:-}" \
    "${NGINX_IMAGE:-}" \
    "${WPCLI_IMAGE:-}"; do
    registry="$(detect_registry_host "${image}" || true)"

    if [[ -z "${registry}" || "${registry}" != *.aliyuncs.com ]]; then
      continue
    fi

    if [[ " ${seen[*]} " == *" ${registry} "* ]]; then
      continue
    fi
    seen+=("${registry}")

    if [[ -n "${ACR_USERNAME}" && -n "${ACR_PASSWORD}" ]]; then
      echo "Logging in to ACR: ${registry}"
      printf '%s' "${ACR_PASSWORD}" | docker login "${registry}" -u "${ACR_USERNAME}" --password-stdin >/dev/null
    else
      echo "ACR image detected: ${registry}"
      echo "No ACR credentials passed in. Continuing with existing docker login state."
    fi
  done
}

pull_required_images() {
  echo "Pulling app images..."
  "${compose_base[@]}" pull db redis wordpress frontend websocket nginx

  if [[ "${WORDPRESS_RUN_INIT}" == "true" ]]; then
    echo "Pulling wpcli image..."
    "${compose_tools[@]}" pull wpcli
  fi
}

wait_for_service() {
  local service="$1"
  local attempts="${2:-30}"
  local delay="${3:-5}"
  local container_id=""
  local status=""

  for ((i = 1; i <= attempts; i++)); do
    container_id="$("${compose_base[@]}" ps -q "${service}" 2>/dev/null || true)"

    if [[ -n "${container_id}" ]]; then
      status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container_id}" 2>/dev/null || echo unknown)"
      echo "${service}: attempt ${i}/${attempts} status=${status}"

      if [[ "${status}" == "healthy" || "${status}" == "running" ]]; then
        return 0
      fi
    else
      echo "${service}: attempt ${i}/${attempts} status=missing"
    fi

    sleep "${delay}"
  done

  echo "Service did not become ready: ${service}"
  return 1
}

show_summary() {
  echo
  echo "Current containers:"
  "${compose_base[@]}" ps
}

verify_wordpress_assets_mounts() {
  if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" != "true" ]]; then
    return 0
  fi

  echo "Verifying WordPress theme and plugin mounts..."
  "${compose_base[@]}" exec -T wordpress sh -lc '
    test -f /var/www/html/wp-content/themes/fd-theme/style.css &&
    test -f /var/www/html/wp-content/plugins/fd-admin-ui/fd-admin-ui.php &&
    test -f /var/www/html/wp-content/plugins/fd-member/index.php &&
    test -f /var/www/html/wp-content/plugins/fd-payment/index.php &&
    test -f /var/www/html/wp-content/plugins/fd-commerce/fd-commerce.php &&
    test -f /var/www/html/wp-content/plugins/fd-content-types/fd-content-types.php &&
    test -f /var/www/html/wp-content/plugins/fd-websocket-push/fd-websocket-push.php &&
    test -f /var/www/html/wp-content/plugins/wp-graphql-jwt-authentication/wp-graphql-jwt-authentication.php &&
    test -f /var/www/html/wp-content/plugins/wp-graphql-tax-query-develop/wp-graphql-tax-query.php
  '
}

validate_http_endpoints() {
  local graphql_response=""
  local frontend_status=""

  if [[ "${HTTPS_ENABLED}" == "true" ]]; then
    echo "Checking frontend HTTP redirect..."
    frontend_status="$(curl -ksS -o /dev/null -w '%{http_code}' -H "Host: ${FRONTEND_DOMAIN}" "http://127.0.0.1:${HTTP_PORT}/")"
    if [[ "${frontend_status}" != "301" && "${frontend_status}" != "308" ]]; then
      echo "Frontend HTTP redirect check failed. status=${frontend_status}"
      exit 1
    fi

    echo "Checking frontend HTTPS..."
    curl -kfsS -I --resolve "${FRONTEND_DOMAIN}:${HTTPS_PORT}:127.0.0.1" "https://${FRONTEND_DOMAIN}:${HTTPS_PORT}/" >/dev/null

    echo "Checking websocket HTTPS..."
    curl -kfsS --resolve "${WS_DOMAIN}:${HTTPS_PORT}:127.0.0.1" "https://${WS_DOMAIN}:${HTTPS_PORT}/health" >/dev/null

    echo "Checking GraphQL route mapping over HTTPS..."
    graphql_response="$(curl -kfsS --resolve "${ADMIN_DOMAIN}:${HTTPS_PORT}:127.0.0.1" --get --data-urlencode 'query={slugMappingTable{slug type id}}' "https://${ADMIN_DOMAIN}:${HTTPS_PORT}/graphql")"
  else
    echo "Checking frontend..."
    curl -fsS -I -H "Host: ${FRONTEND_DOMAIN}" "http://127.0.0.1:${HTTP_PORT}/" >/dev/null

    echo "Checking websocket..."
    curl -fsS -H "Host: ${WS_DOMAIN}" "http://127.0.0.1:${HTTP_PORT}/health" >/dev/null

    echo "Checking GraphQL route mapping..."
    graphql_response="$(curl -fsS --get -H "Host: ${ADMIN_DOMAIN}" --data-urlencode 'query={slugMappingTable{slug type id}}' "http://127.0.0.1:${HTTP_PORT}/graphql")"
  fi

  if [[ "${graphql_response}" == *'"errors"'* ]]; then
    echo "GraphQL route mapping check failed."
    printf '%s\n' "${graphql_response}"
    exit 1
  fi
}

echo "Starting safe stack update..."
login_acr_if_needed

if need_wordpress_asset_sync; then
  echo "WordPress release assets changed or missing. Syncing assets..."
  ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/fetch-wordpress-assets.sh"
else
  echo "WordPress release assets are already in sync."
fi

pull_required_images

echo "Updating core services..."
"${compose_base[@]}" up -d db redis
"${compose_base[@]}" up -d --force-recreate wordpress
wait_for_service wordpress 30 3
verify_wordpress_assets_mounts

if [[ "${WORDPRESS_RUN_INIT}" == "true" ]]; then
  echo "Running WordPress init..."
  ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/init-wordpress.sh"
fi

echo "Updating app services..."
"${compose_base[@]}" up -d --force-recreate frontend websocket nginx
wait_for_service frontend 40 3
wait_for_service websocket 40 3
wait_for_service nginx 20 2
validate_http_endpoints

show_summary
echo
echo "Safe stack update finished."
