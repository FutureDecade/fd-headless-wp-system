#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/common.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/stack-bootstrap.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env file. Run: cp .env.example .env"
  exit 1
fi

if [[ -n "${FD_STACK_BOOTSTRAP_JSON:-}" || -n "${FD_STACK_DEPLOY_TOKEN:-}" ]]; then
  if ! load_stack_bootstrap; then
    echo "FD Stack 部署预设加载失败，无法继续运行时更新。"
    exit 1
  fi
fi

ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/preflight-check.sh"
load_env_file "${ENV_FILE}"

ACR_USERNAME="${ACR_USERNAME:-}"
ACR_PASSWORD="${ACR_PASSWORD:-}"
SKIP_IMAGE_PULL="${SKIP_IMAGE_PULL:-false}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_ENABLED="${HTTPS_ENABLED:-false}"
HTTPS_PORT="${HTTPS_PORT:-443}"

compose_files=(
  -f "${ROOT_DIR}/docker-compose.yml"
)

if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS:-false}" == "true" ]]; then
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

  if [[ "${SKIP_IMAGE_PULL}" == "true" ]]; then
    echo "SKIP_IMAGE_PULL=true, skipping ACR login."
    return 0
  fi

  for image in \
    "${FRONTEND_IMAGE:-}" \
    "${WEBSOCKET_IMAGE:-}" \
    "${NGINX_IMAGE:-}"; do
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

pull_runtime_images() {
  if [[ "${SKIP_IMAGE_PULL}" == "true" ]]; then
    echo "SKIP_IMAGE_PULL=true, skipping runtime image pulls."
    return 0
  fi

  echo "Pulling runtime service images..."
  "${compose_base[@]}" pull frontend websocket nginx
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

validate_runtime_endpoints() {
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

show_summary() {
  echo
  echo "Current runtime containers:"
  "${compose_base[@]}" ps frontend websocket nginx
}

echo "Starting runtime-only service update..."
login_acr_if_needed
pull_runtime_images

echo "Recreating runtime services without touching WordPress..."
"${compose_base[@]}" up -d --no-deps --force-recreate frontend websocket nginx
wait_for_service frontend 40 3
wait_for_service websocket 40 3
wait_for_service nginx 20 2
validate_runtime_endpoints

show_summary
echo
echo "Runtime-only service update finished."
