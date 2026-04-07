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

load_env_file "${ENV_FILE}"

WORDPRESS_FETCH_RELEASE_ASSETS="${WORDPRESS_FETCH_RELEASE_ASSETS:-false}"
WORDPRESS_DEMO_DATA_FILE="${WORDPRESS_DEMO_DATA_FILE:-demo-data/demo-cpt-content.v1.json}"
WORDPRESS_FORCE_DEMO_DATA_IMPORT="${WORDPRESS_FORCE_DEMO_DATA_IMPORT:-false}"

compose_files=(
  -f "${ROOT_DIR}/docker-compose.yml"
)

if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" == "true" ]]; then
  compose_files+=(
    -f "${ROOT_DIR}/compose/wordpress-assets.override.yml"
  )
fi

compose_base=(docker compose "${compose_files[@]}" --env-file "${ENV_FILE}")

local_demo_data_path="${WORDPRESS_DEMO_DATA_FILE}"

if [[ "${local_demo_data_path}" != /* ]]; then
  local_demo_data_path="${ROOT_DIR}/${local_demo_data_path}"
fi

if [[ ! -f "${local_demo_data_path}" ]]; then
  echo "Demo data file not found: ${local_demo_data_path}"
  exit 1
fi

local_importer_path="${ROOT_DIR}/scripts/import-wordpress-demo-data.remote.php"

if [[ ! -f "${local_importer_path}" ]]; then
  echo "Demo data importer not found: ${local_importer_path}"
  exit 1
fi

wordpress_container_id="$("${compose_base[@]}" ps -q wordpress)"

if [[ -z "${wordpress_container_id}" ]]; then
  echo "WordPress container is not running."
  exit 1
fi

remote_dir="/var/www/html/wp-content/fd-demo-import"
remote_demo_data_path="${remote_dir}/$(basename "${local_demo_data_path}")"
remote_importer_path="${remote_dir}/import-wordpress-demo-data.remote.php"

echo "Preparing demo data import files inside the WordPress container..."
"${compose_base[@]}" exec -T wordpress sh -lc "mkdir -p '${remote_dir}'"

docker cp "${local_importer_path}" "${wordpress_container_id}:${remote_importer_path}"
docker cp "${local_demo_data_path}" "${wordpress_container_id}:${remote_demo_data_path}"

import_command=(
  "${compose_base[@]}"
  exec
  -T
  wordpress
  php
  "${remote_importer_path}"
  "${remote_demo_data_path}"
)

if [[ "${WORDPRESS_FORCE_DEMO_DATA_IMPORT}" == "true" ]]; then
  import_command+=(--force)
fi

echo "Importing demo data package: $(basename "${local_demo_data_path}")"
"${import_command[@]}"
