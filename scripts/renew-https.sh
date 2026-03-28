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

HTTPS_ENABLED="${HTTPS_ENABLED:-false}"
WORDPRESS_FETCH_RELEASE_ASSETS="${WORDPRESS_FETCH_RELEASE_ASSETS:-false}"
ACR_USERNAME="${ACR_USERNAME:-}"
ACR_PASSWORD="${ACR_PASSWORD:-}"

if [[ "${HTTPS_ENABLED}" != "true" ]]; then
  echo "HTTPS is not enabled in .env. Nothing to renew."
  exit 1
fi

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

login_registry_if_needed() {
  local image="$1"
  local registry=""

  registry="$(detect_registry_host "${image}" || true)"
  if [[ -z "${registry}" || "${registry}" != *.aliyuncs.com ]]; then
    return 0
  fi

  if [[ -z "${ACR_USERNAME}" || -z "${ACR_PASSWORD}" ]]; then
    echo "CERTBOT_IMAGE uses ACR, but ACR_USERNAME / ACR_PASSWORD were not provided."
    exit 1
  fi

  echo "Logging in to ACR: ${registry}"
  printf '%s' "${ACR_PASSWORD}" | docker login "${registry}" -u "${ACR_USERNAME}" --password-stdin >/dev/null
}

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

compose_tools=(
  docker compose
  "${compose_files[@]}"
  --profile tools
  --env-file "${ENV_FILE}"
)

compose_base=(
  docker compose
  "${compose_files[@]}"
  --env-file "${ENV_FILE}"
)

login_registry_if_needed "${CERTBOT_IMAGE:-}"

echo "Renewing certificates..."
"${compose_tools[@]}" run --rm certbot renew --webroot -w /var/www/certbot --no-random-sleep-on-renew

echo "Reloading nginx after renewal..."
"${compose_base[@]}" up -d --force-recreate nginx

echo
echo "HTTPS renew finished."
