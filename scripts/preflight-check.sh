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
  perl
  openssl
)

for cmd in "${required_commands[@]}"; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}"
    exit 1
  fi
done

required_keys=(
  FRONTEND_DOMAIN
  ADMIN_DOMAIN
  WS_DOMAIN
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

WORDPRESS_FETCH_RELEASE_ASSETS="${WORDPRESS_FETCH_RELEASE_ASSETS:-false}"
WORDPRESS_RUN_INIT="${WORDPRESS_RUN_INIT:-false}"

compose_files=(
  -f "${ROOT_DIR}/docker-compose.yml"
)

if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" == "true" ]]; then
  for cmd in gh unzip; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      echo "Missing required command for WordPress asset fetch: ${cmd}"
      exit 1
    fi
  done

  if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Run: gh auth login"
    exit 1
  fi

  compose_files+=(
    -f "${ROOT_DIR}/compose/wordpress-assets.override.yml"
  )
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
