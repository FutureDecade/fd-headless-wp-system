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

LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
LETSENCRYPT_STAGING="${LETSENCRYPT_STAGING:-false}"
WORDPRESS_FETCH_RELEASE_ASSETS="${WORDPRESS_FETCH_RELEASE_ASSETS:-false}"
ACR_USERNAME="${ACR_USERNAME:-}"
ACR_PASSWORD="${ACR_PASSWORD:-}"
GH_TOKEN="${GH_TOKEN:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

if [[ -z "${LETSENCRYPT_EMAIL}" || "${LETSENCRYPT_EMAIL}" == "admin@example.com" ]]; then
  echo "Set LETSENCRYPT_EMAIL in .env before requesting certificates."
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

compose_tools=(
  docker compose
  "${compose_files[@]}"
  --profile tools
  --env-file "${ENV_FILE}"
)

mkdir -p "${ROOT_DIR}/runtime/certbot/www" "${ROOT_DIR}/runtime/letsencrypt"

echo "Ensuring current HTTP stack is healthy before requesting certificates..."
ENV_FILE="${ENV_FILE}" \
ACR_USERNAME="${ACR_USERNAME}" \
ACR_PASSWORD="${ACR_PASSWORD}" \
GH_TOKEN="${GH_TOKEN}" \
GITHUB_TOKEN="${GITHUB_TOKEN}" \
bash "${ROOT_DIR}/scripts/update-stack.sh"

login_registry_if_needed "${CERTBOT_IMAGE:-}"

certbot_args=(
  certonly
  --webroot
  -w /var/www/certbot
  --agree-tos
  --no-eff-email
  --keep-until-expiring
  --non-interactive
  --email "${LETSENCRYPT_EMAIL}"
  -d "${FRONTEND_DOMAIN}"
  -d "${ADMIN_DOMAIN}"
  -d "${WS_DOMAIN}"
)

if [[ "${LETSENCRYPT_STAGING}" == "true" ]]; then
  certbot_args+=(
    --staging
  )
fi

echo "Requesting Let's Encrypt certificates..."
"${compose_tools[@]}" run --rm certbot "${certbot_args[@]}"

cert_dir="${ROOT_DIR}/runtime/letsencrypt/live/${FRONTEND_DOMAIN}"
if [[ ! -f "${cert_dir}/fullchain.pem" || ! -f "${cert_dir}/privkey.pem" ]]; then
  echo "Certificate request finished, but expected files were not found: ${cert_dir}"
  exit 1
fi

set_env_value "${ENV_FILE}" "HTTPS_ENABLED" "true"
set_env_value "${ENV_FILE}" "HTTPS_PORT" "${HTTPS_PORT:-443}"
set_env_value "${ENV_FILE}" "PUBLIC_SCHEME" "https"
set_env_value "${ENV_FILE}" "WEBSOCKET_PUBLIC_SCHEME" "wss"

echo "HTTPS settings were written into ${ENV_FILE}"
echo "Reloading stack with HTTPS enabled..."
ENV_FILE="${ENV_FILE}" \
ACR_USERNAME="${ACR_USERNAME}" \
ACR_PASSWORD="${ACR_PASSWORD}" \
GH_TOKEN="${GH_TOKEN}" \
GITHUB_TOKEN="${GITHUB_TOKEN}" \
bash "${ROOT_DIR}/scripts/update-stack.sh"

echo
echo "HTTPS setup finished."
