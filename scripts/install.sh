#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
  bash "${ROOT_DIR}/scripts/bootstrap-env.sh"
fi

ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/preflight-check.sh"

set -a
source "${ENV_FILE}"
set +a

WORDPRESS_FETCH_RELEASE_ASSETS="${WORDPRESS_FETCH_RELEASE_ASSETS:-false}"

compose_files=(
  -f "${ROOT_DIR}/docker-compose.yml"
)

if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" == "true" ]]; then
  ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/fetch-wordpress-assets.sh"
  compose_files+=(
    -f "${ROOT_DIR}/compose/wordpress-assets.override.yml"
  )
fi

echo "Starting services..."
docker compose "${compose_files[@]}" --env-file "${ENV_FILE}" up -d

echo
echo "Bootstrap install finished."
echo "This is an early delivery scaffold, not the final production installer."
