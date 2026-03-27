#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/common.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
  bash "${ROOT_DIR}/scripts/bootstrap-env.sh"
fi

ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/preflight-check.sh"

load_env_file "${ENV_FILE}"

WORDPRESS_FETCH_RELEASE_ASSETS="${WORDPRESS_FETCH_RELEASE_ASSETS:-false}"
WORDPRESS_RUN_INIT="${WORDPRESS_RUN_INIT:-false}"

compose_files=(
  -f "${ROOT_DIR}/docker-compose.yml"
)

if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" == "true" ]]; then
  ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/fetch-wordpress-assets.sh"
  compose_files+=(
    -f "${ROOT_DIR}/compose/wordpress-assets.override.yml"
  )
fi

echo "Starting core services..."
docker compose "${compose_files[@]}" --env-file "${ENV_FILE}" up -d db redis wordpress

if [[ "${WORDPRESS_RUN_INIT}" == "true" ]]; then
  ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/init-wordpress.sh"
fi

echo "Starting remaining services..."
docker compose "${compose_files[@]}" --env-file "${ENV_FILE}" up -d frontend websocket nginx

echo
echo "Bootstrap install finished."
echo "This is an early delivery scaffold, not the final production installer."
