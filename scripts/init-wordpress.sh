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

WORDPRESS_RUN_INIT="${WORDPRESS_RUN_INIT:-false}"
WORDPRESS_FETCH_RELEASE_ASSETS="${WORDPRESS_FETCH_RELEASE_ASSETS:-false}"
WORDPRESS_ACTIVATE_THEME="${WORDPRESS_ACTIVATE_THEME:-true}"
WORDPRESS_ACTIVATE_CORE_PLUGINS="${WORDPRESS_ACTIVATE_CORE_PLUGINS:-true}"
PUBLIC_SCHEME="${PUBLIC_SCHEME:-http}"

if [[ "${WORDPRESS_RUN_INIT}" != "true" ]]; then
  echo "WORDPRESS_RUN_INIT is not enabled. Skipping WordPress init."
  exit 0
fi

compose_files=(
  -f "${ROOT_DIR}/docker-compose.yml"
)

if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" == "true" ]]; then
  compose_files+=(
    -f "${ROOT_DIR}/compose/wordpress-assets.override.yml"
  )
fi

compose_base=(docker compose "${compose_files[@]}" --env-file "${ENV_FILE}")
compose_wpcli=(docker compose "${compose_files[@]}" --profile tools --env-file "${ENV_FILE}")

run_wp() {
  "${compose_wpcli[@]}" run --rm -T wpcli wp "$@" --allow-root
}

wait_for_wp_config() {
  local attempts=30
  local delay=3

  for ((i = 1; i <= attempts; i++)); do
    if "${compose_base[@]}" exec -T wordpress sh -lc 'test -f /var/www/html/wp-config.php'; then
      return 0
    fi
    sleep "${delay}"
  done

  echo "Timed out waiting for wp-config.php"
  exit 1
}

wait_for_database() {
  local attempts=30
  local delay=3

  for ((i = 1; i <= attempts; i++)); do
    if run_wp db check >/dev/null 2>&1; then
      return 0
    fi
    sleep "${delay}"
  done

  echo "Timed out waiting for WordPress database access"
  exit 1
}

activate_plugin_if_present() {
  local plugin_slug="$1"

  if ! run_wp plugin is-installed "${plugin_slug}" >/dev/null 2>&1; then
    echo "Plugin not found in runtime assets: ${plugin_slug}"
    return 0
  fi

  if run_wp plugin is-active "${plugin_slug}" >/dev/null 2>&1; then
    echo "Plugin already active: ${plugin_slug}"
    return 0
  fi

  echo "Activating plugin: ${plugin_slug}"
  run_wp plugin activate "${plugin_slug}" >/dev/null
}

wait_for_wp_config
wait_for_database

if run_wp core is-installed >/dev/null 2>&1; then
  echo "WordPress is already installed."
else
  echo "Running initial WordPress install..."
  run_wp core install \
    --url="${PUBLIC_SCHEME}://${ADMIN_DOMAIN}" \
    --title="${WORDPRESS_TITLE}" \
    --admin_user="${WORDPRESS_ADMIN_USER}" \
    --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
    --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
    --skip-email >/dev/null
fi

if [[ "${WORDPRESS_ACTIVATE_THEME}" == "true" ]] && run_wp theme is-installed fd-theme >/dev/null 2>&1; then
  if ! run_wp theme is-active fd-theme >/dev/null 2>&1; then
    echo "Activating theme: fd-theme"
    run_wp theme activate fd-theme >/dev/null
  else
    echo "Theme already active: fd-theme"
  fi
fi

if [[ "${WORDPRESS_ACTIVATE_CORE_PLUGINS}" == "true" ]]; then
  activate_plugin_if_present "fd-member"
  activate_plugin_if_present "fd-payment"
  activate_plugin_if_present "fd-commerce"
fi

echo "WordPress init completed."
