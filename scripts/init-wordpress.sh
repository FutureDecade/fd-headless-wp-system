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
WORDPRESS_INSTALL_WPGRAPHQL="${WORDPRESS_INSTALL_WPGRAPHQL:-true}"
WORDPRESS_WPGRAPHQL_SOURCE="${WORDPRESS_WPGRAPHQL_SOURCE:-wp-graphql}"
WORDPRESS_INSTALL_REDIS_CACHE="${WORDPRESS_INSTALL_REDIS_CACHE:-true}"
WORDPRESS_REDIS_CACHE_SOURCE="${WORDPRESS_REDIS_CACHE_SOURCE:-redis-cache}"
WORDPRESS_INSTALL_CLASSIC_EDITOR="${WORDPRESS_INSTALL_CLASSIC_EDITOR:-true}"
WORDPRESS_CLASSIC_EDITOR_SOURCE="${WORDPRESS_CLASSIC_EDITOR_SOURCE:-classic-editor}"
WORDPRESS_ENABLE_REDIS_OBJECT_CACHE="${WORDPRESS_ENABLE_REDIS_OBJECT_CACHE:-true}"
WORDPRESS_PERMALINK_STRUCTURE="${WORDPRESS_PERMALINK_STRUCTURE:-/%postname%/}"
WORDPRESS_IMPORT_DEMO_DATA="${WORDPRESS_IMPORT_DEMO_DATA:-true}"
WORDPRESS_DEMO_DATA_FILE="${WORDPRESS_DEMO_DATA_FILE:-demo-data/demo-cpt-content.v1.json}"
WORDPRESS_FORCE_DEMO_DATA_IMPORT="${WORDPRESS_FORCE_DEMO_DATA_IMPORT:-false}"
WP_APP_USER="${WP_APP_USER:-}"
WP_APP_PASS="${WP_APP_PASS:-}"
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
  local last_error=""
  local check_output=""

  for ((i = 1; i <= attempts; i++)); do
    check_output="$("${compose_base[@]}" exec -T wordpress php -r '$host = getenv("WORDPRESS_DB_HOST") ?: "db"; $db = getenv("WORDPRESS_DB_NAME"); $user = getenv("WORDPRESS_DB_USER"); $pass = getenv("WORDPRESS_DB_PASSWORD"); [$hostname, $port] = array_pad(explode(":", $host, 2), 2, 3306); mysqli_report(MYSQLI_REPORT_OFF); $mysqli = @new mysqli($hostname, $user, $pass, $db, (int) $port); if ($mysqli->connect_errno) { fwrite(STDERR, $mysqli->connect_error . PHP_EOL); exit(1); } $mysqli->close();' 2>&1)" && {
      return 0
    }
    last_error="${check_output}"

    if [[ "${last_error}" == *"Access denied for user"* ]]; then
      echo "WordPress database credentials do not match the existing MariaDB data volume."
      echo "Current .env credentials were rejected by MariaDB."
      echo "If this server is being re-installed from a fresh bootstrap token, clear the existing fd-headless-wp database volumes before retrying."
      printf 'MariaDB said: %s\n' "${last_error}"
      exit 1
    fi

    sleep "${delay}"
  done

  echo "Timed out waiting for WordPress database access"
  if [[ -n "${last_error}" ]]; then
    printf 'Last database error: %s\n' "${last_error}"
  fi
  exit 1
}

activate_plugin_if_present() {
  local plugin_slug="$1"

  if ! run_wp plugin is-installed "${plugin_slug}" >/dev/null 2>&1; then
    echo "Plugin not installed: ${plugin_slug}"
    return 0
  fi

  if run_wp plugin is-active "${plugin_slug}" >/dev/null 2>&1; then
    echo "Plugin already active: ${plugin_slug}"
    return 0
  fi

  echo "Activating plugin: ${plugin_slug}"
  run_wp plugin activate "${plugin_slug}" >/dev/null
}

install_plugin_if_missing() {
  local plugin_slug="$1"
  local plugin_source="$2"

  if run_wp plugin is-installed "${plugin_slug}" >/dev/null 2>&1; then
    echo "Plugin already installed: ${plugin_slug}"
    return 0
  fi

  echo "Installing plugin: ${plugin_slug} (source: ${plugin_source})"
  run_wp plugin install "${plugin_source}" >/dev/null
}

redis_object_cache_is_enabled() {
  local enabled=""

  enabled="$(run_wp eval 'echo file_exists( WP_CONTENT_DIR . "/object-cache.php" ) ? "yes" : "no";' 2>/dev/null || true)"
  [[ "${enabled}" == "yes" ]]
}

enable_redis_object_cache() {
  if ! run_wp plugin is-active "redis-cache" >/dev/null 2>&1; then
    echo "Redis Cache plugin is not active. Skipping object cache enable."
    return 0
  fi

  if redis_object_cache_is_enabled; then
    echo "Redis object cache already enabled."
    return 0
  fi

  echo "Enabling Redis object cache..."
  if run_wp redis enable >/dev/null 2>&1; then
    echo "Redis object cache enabled."
  else
    echo "Redis object cache enable failed. Continuing without drop-in."
  fi
}

apply_legacy_plugin_defaults() {
  if [[ "${WORDPRESS_INSTALL_CLASSIC_EDITOR}" == "true" ]] && run_wp plugin is-active "classic-editor" >/dev/null 2>&1; then
    echo "Applying legacy Classic Editor defaults..."
    run_wp option update "classic-editor-replace" "classic" >/dev/null
    run_wp option update "classic-editor-allow-users" "disallow" >/dev/null
  fi

  if [[ "${WORDPRESS_INSTALL_WPGRAPHQL}" == "true" ]] && run_wp plugin is-active "wp-graphql" >/dev/null 2>&1; then
    echo "Applying legacy WPGraphQL defaults..."
    run_wp eval '
update_option( "graphql_general_settings", array(
    "query_depth_enabled" => "on",
    "query_depth_max" => 10,
) );

update_option( "graphql_cache_section", array(
    "global_max_age" => null,
    "cache_toggle" => "off",
    "global_ttl" => null,
    "log_purge_events" => "off",
    "purge_all" => false,
) );

update_option( "graphql_persisted_queries_section", array(
    "grant_mode" => "public",
    "editor_display" => "off",
    "query_garbage_collect" => "off",
    "query_garbage_collect_age" => 30,
) );
' >/dev/null
  fi

  if [[ "${WORDPRESS_INSTALL_REDIS_CACHE}" == "true" ]] && run_wp plugin is-active "redis-cache" >/dev/null 2>&1; then
    if redis_object_cache_is_enabled; then
      echo "Legacy Redis Cache defaults already match: object cache drop-in is enabled."
    elif [[ "${WORDPRESS_ENABLE_REDIS_OBJECT_CACHE}" == "true" ]]; then
      echo "Applying legacy Redis Cache defaults..."
      enable_redis_object_cache
    else
      echo "Legacy Redis Cache defaults expect object cache enabled, but WORDPRESS_ENABLE_REDIS_OBJECT_CACHE=false."
    fi
  fi
}

ensure_permalink_structure() {
  local target_structure="$1"
  local current_structure=""

  if [[ -z "${target_structure}" ]]; then
    echo "Permalink structure is empty. Skipping rewrite configuration."
    return 0
  fi

  current_structure="$(run_wp option get permalink_structure 2>/dev/null || true)"

  if [[ "${current_structure}" != "${target_structure}" ]]; then
    echo "Setting permalink structure: ${target_structure}"
    run_wp rewrite structure "${target_structure}" --hard >/dev/null
  else
    echo "Permalink structure already set: ${target_structure}"
  fi

  echo "Flushing rewrite rules..."
  run_wp rewrite flush --hard >/dev/null
}

flush_graphql_schema_cache() {
  echo "Flushing GraphQL schema cache..."
  run_wp eval 'global $wpdb;
	do_action( "graphql_cache_clear" );
	do_action( "graphql_flush_schema_cache" );
	$queries = [
	    "DELETE FROM {$wpdb->options} WHERE option_name LIKE \"_transient_graphql%\" OR option_name LIKE \"_transient_timeout_graphql%\" OR option_name LIKE \"_transient_wpgraphql%\" OR option_name LIKE \"_transient_timeout_wpgraphql%\"",
	    "DELETE FROM {$wpdb->options} WHERE option_name LIKE \"_transient_acf_graphql%\" OR option_name LIKE \"_transient_timeout_acf_graphql%\"",
	];
foreach ( $queries as $query ) {
    $wpdb->query( $query );
}
	delete_option( "graphql_schema_version" );
	delete_option( "wpgraphql_schema_entry_point" );
	wp_cache_flush();' >/dev/null
}

seed_delivery_sample_page() {
  local sample_page_id=""
  local sample_page_content="<p>Your headless WordPress delivery stack is running.</p><p>Replace this page with your own published content after installation.</p>"

  sample_page_id="$(run_wp post list --post_type=page --name=sample-page --format=ids 2>/dev/null || true)"
  sample_page_id="$(printf '%s' "${sample_page_id}" | tr -d '[:space:]')"

  if [[ -z "${sample_page_id}" ]]; then
    echo "Creating delivery sample page..."
    run_wp post create \
      --post_type=page \
      --post_status=publish \
      --post_title="Sample Page" \
      --post_name="sample-page" \
      --post_content="${sample_page_content}" >/dev/null
    return 0
  fi

  echo "Normalizing sample page content for delivery validation..."
  run_wp post update "${sample_page_id}" \
    --post_status=publish \
    --post_title="Sample Page" \
    --post_content="${sample_page_content}" >/dev/null
}

import_demo_data() {
  if [[ "${WORDPRESS_IMPORT_DEMO_DATA}" != "true" ]]; then
    echo "WORDPRESS_IMPORT_DEMO_DATA is disabled. Skipping demo data import."
    return 1
  fi

  echo "Importing demo data package: ${WORDPRESS_DEMO_DATA_FILE}"
  WORDPRESS_FETCH_RELEASE_ASSETS="${WORDPRESS_FETCH_RELEASE_ASSETS}" \
  WORDPRESS_DEMO_DATA_FILE="${WORDPRESS_DEMO_DATA_FILE}" \
  WORDPRESS_FORCE_DEMO_DATA_IMPORT="${WORDPRESS_FORCE_DEMO_DATA_IMPORT}" \
  ENV_FILE="${ENV_FILE}" \
  bash "${ROOT_DIR}/scripts/import-wordpress-demo-data.sh"
}

ensure_wordpress_application_password() {
  local app_user="${WP_APP_USER:-${WORDPRESS_ADMIN_USER}}"
  local app_password="${WP_APP_PASS:-}"
  local app_name="fd-frontend-delivery"

  if ! run_wp user get "${app_user}" --field=ID >/dev/null 2>&1; then
    app_user="${WORDPRESS_ADMIN_USER}"
    app_password=""
  fi

  if [[ -n "${app_user}" && -n "${app_password}" ]]; then
    echo "WordPress application password already configured for frontend."
    return 0
  fi

  echo "Generating WordPress application password for frontend runtime..."
  app_password="$(run_wp user application-password create "${app_user}" "${app_name}" --porcelain | tr -d '[:space:]')"

  if [[ -z "${app_password}" ]]; then
    echo "Failed to generate WordPress application password."
    exit 1
  fi

  set_env_value "${ENV_FILE}" "WP_APP_USER" "${app_user}"
  set_env_value "${ENV_FILE}" "WP_APP_PASS" "${app_password}"
  export "WP_APP_USER=${app_user}"
  export "WP_APP_PASS=${app_password}"
}

verify_graphql_route_mapping() {
  local attempts=6
  local delay=2
  local output=""

  for ((i = 1; i <= attempts; i++)); do
    output="$(run_wp eval '
	$result = function_exists( "do_graphql_request" )
	    ? do_graphql_request( "query { slugMappingTable { slug type id } }" )
	    : null;

	if ( ! is_array( $result ) ) {
	    fwrite( STDERR, "GraphQL request handler is unavailable." . PHP_EOL );
	    exit( 1 );
	}

	$errors = $result["errors"] ?? [];
	$rows = $result["data"]["slugMappingTable"] ?? null;

	if ( ! empty( $errors ) || ! is_array( $rows ) || count( $rows ) === 0 ) {
	    fwrite( STDERR, wp_json_encode( $result ) . PHP_EOL );
	    exit( 1 );
	}

	echo wp_json_encode( $rows );
	' 2>/dev/null || true)"

    if [[ -n "${output}" ]]; then
      echo "GraphQL route mapping is ready."
      return 0
    fi

    echo "GraphQL route mapping is not ready yet. Retrying..."
    flush_graphql_schema_cache
    sleep "${delay}"
  done

  echo "GraphQL route mapping did not become ready after repeated retries."
  run_wp eval '
	$result = function_exists( "do_graphql_request" )
	    ? do_graphql_request( "query { slugMappingTable { slug type id } }" )
	    : null;
	echo wp_json_encode( $result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES ) . PHP_EOL;
	exit( 1 );
	'
}

wait_for_wp_config
wait_for_database

fresh_install="false"

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
  fresh_install="true"
fi

if [[ "${WORDPRESS_ACTIVATE_THEME}" == "true" ]] && run_wp theme is-installed fd-theme >/dev/null 2>&1; then
  if ! run_wp theme is-active fd-theme >/dev/null 2>&1; then
    echo "Activating theme: fd-theme"
    run_wp theme activate fd-theme >/dev/null
  else
    echo "Theme already active: fd-theme"
  fi
fi

if [[ "${WORDPRESS_INSTALL_WPGRAPHQL}" == "true" ]]; then
  install_plugin_if_missing "wp-graphql" "${WORDPRESS_WPGRAPHQL_SOURCE}"
  activate_plugin_if_present "wp-graphql"
fi

if [[ "${WORDPRESS_INSTALL_REDIS_CACHE}" == "true" ]]; then
  install_plugin_if_missing "redis-cache" "${WORDPRESS_REDIS_CACHE_SOURCE}"
  activate_plugin_if_present "redis-cache"

  if [[ "${WORDPRESS_ENABLE_REDIS_OBJECT_CACHE}" == "true" ]]; then
    enable_redis_object_cache
  fi
fi

if [[ "${WORDPRESS_INSTALL_CLASSIC_EDITOR}" == "true" ]]; then
  install_plugin_if_missing "classic-editor" "${WORDPRESS_CLASSIC_EDITOR_SOURCE}"
  activate_plugin_if_present "classic-editor"
fi

if [[ "${WORDPRESS_ACTIVATE_CORE_PLUGINS}" == "true" ]]; then
  activate_plugin_if_present "fd-admin-ui"
  activate_plugin_if_present "fd-member"
  activate_plugin_if_present "fd-payment"
  activate_plugin_if_present "fd-commerce"
  activate_plugin_if_present "fd-content-types"
  activate_plugin_if_present "fd-ai-router"
  activate_plugin_if_present "fd-websocket-push"
  activate_plugin_if_present "wp-graphql-jwt-authentication"
  activate_plugin_if_present "wp-graphql-tax-query-develop"
fi

ensure_wordpress_application_password

if [[ "${fresh_install}" == "true" ]]; then
  apply_legacy_plugin_defaults

  if ! import_demo_data; then
    seed_delivery_sample_page
  fi
elif [[ "${WORDPRESS_IMPORT_DEMO_DATA}" == "true" && "${WORDPRESS_FORCE_DEMO_DATA_IMPORT}" == "true" ]]; then
  apply_legacy_plugin_defaults
  import_demo_data
fi

ensure_permalink_structure "${WORDPRESS_PERMALINK_STRUCTURE}"
flush_graphql_schema_cache
verify_graphql_route_mapping

echo "WordPress init completed."
