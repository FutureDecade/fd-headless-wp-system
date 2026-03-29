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
FORCE_WORDPRESS_ASSET_FETCH="${FORCE_WORDPRESS_ASSET_FETCH:-false}"

if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS}" != "true" ]]; then
  echo "WORDPRESS_FETCH_RELEASE_ASSETS is not enabled. Skipping fetch."
  exit 0
fi

WORDPRESS_RELEASE_OWNER="${WORDPRESS_RELEASE_OWNER:-FutureDecade}"
FD_THEME_RELEASE_TAG="${FD_THEME_RELEASE_TAG:-v1.0.6}"
FD_ADMIN_UI_RELEASE_TAG="${FD_ADMIN_UI_RELEASE_TAG:-v1.3.1}"
FD_MEMBER_RELEASE_TAG="${FD_MEMBER_RELEASE_TAG:-v1.0.1}"
FD_PAYMENT_RELEASE_TAG="${FD_PAYMENT_RELEASE_TAG:-v1.0.0}"
FD_COMMERCE_RELEASE_TAG="${FD_COMMERCE_RELEASE_TAG:-v1.0.0}"
FD_CONTENT_TYPES_RELEASE_TAG="${FD_CONTENT_TYPES_RELEASE_TAG:-v0.1.0}"
FD_WEBSOCKET_PUSH_RELEASE_TAG="${FD_WEBSOCKET_PUSH_RELEASE_TAG:-v1.0.0}"
WPGRAPHQL_JWT_AUTH_RELEASE_TAG="${WPGRAPHQL_JWT_AUTH_RELEASE_TAG:-v0.7.2}"
WPGRAPHQL_TAX_QUERY_REF="${WPGRAPHQL_TAX_QUERY_REF:-v0.2.0}"

RUNTIME_ROOT="${ROOT_DIR}/runtime/wp-content"
THEMES_DIR="${RUNTIME_ROOT}/themes"
PLUGINS_DIR="${RUNTIME_ROOT}/plugins"
LOCK_FILE="${ROOT_DIR}/runtime/wordpress-assets.lock"
mkdir -p "${ROOT_DIR}/tmp"
TMP_DIR="$(mktemp -d "${ROOT_DIR}/tmp/wp-assets.XXXXXX")"

cleanup() {
  rm -rf "${TMP_DIR}"
}

trap cleanup EXIT

mkdir -p "${THEMES_DIR}" "${PLUGINS_DIR}"

desired_assets_lock() {
  cat <<EOF
fd-theme=${FD_THEME_RELEASE_TAG}
fd-admin-ui=${FD_ADMIN_UI_RELEASE_TAG}
fd-member=${FD_MEMBER_RELEASE_TAG}
fd-payment=${FD_PAYMENT_RELEASE_TAG}
fd-commerce=${FD_COMMERCE_RELEASE_TAG}
fd-content-types=${FD_CONTENT_TYPES_RELEASE_TAG}
fd-websocket-push=${FD_WEBSOCKET_PUSH_RELEASE_TAG}
wp-graphql-jwt-authentication=${WPGRAPHQL_JWT_AUTH_RELEASE_TAG}
wp-graphql-tax-query-develop=${WPGRAPHQL_TAX_QUERY_REF}
EOF
}

assets_already_match() {
  if [[ ! -f "${LOCK_FILE}" ]]; then
    return 1
  fi

  if [[ ! -f "${THEMES_DIR}/fd-theme/style.css" ]]; then
    return 1
  fi

  if [[ ! -f "${PLUGINS_DIR}/fd-admin-ui/fd-admin-ui.php" ]]; then
    return 1
  fi

  if [[ ! -f "${PLUGINS_DIR}/fd-member/index.php" ]]; then
    return 1
  fi

  if [[ ! -f "${PLUGINS_DIR}/fd-payment/index.php" ]]; then
    return 1
  fi

  if [[ ! -f "${PLUGINS_DIR}/fd-commerce/fd-commerce.php" ]]; then
    return 1
  fi

  if [[ ! -f "${PLUGINS_DIR}/fd-content-types/fd-content-types.php" ]]; then
    return 1
  fi

  if [[ ! -f "${PLUGINS_DIR}/fd-websocket-push/fd-websocket-push.php" ]]; then
    return 1
  fi

  if [[ ! -f "${PLUGINS_DIR}/wp-graphql-jwt-authentication/wp-graphql-jwt-authentication.php" ]]; then
    return 1
  fi

  if [[ ! -f "${PLUGINS_DIR}/wp-graphql-tax-query-develop/wp-graphql-tax-query.php" ]]; then
    return 1
  fi

  local current_lock
  current_lock="$(cat "${LOCK_FILE}")"

  [[ "${current_lock}" == "$(desired_assets_lock)" ]]
}

if [[ "${FORCE_WORDPRESS_ASSET_FETCH}" != "true" ]] && assets_already_match; then
  echo "WordPress release assets already match requested tags. Skipping fetch."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Missing required command: gh"
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "Missing required command: unzip"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Missing required command: curl"
  exit 1
fi

if [[ -z "${GH_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

download_release_asset() {
  local repo="$1"
  local release_tag="$2"
  local asset_name="$3"
  local expected_dir="$4"
  local target_dir="$5"
  local cache_key="$6"
  local expected_main_file="${7:-}"
  local package_dir="${TMP_DIR}/${cache_key}"
  local extracted_dir="${TMP_DIR}/extracted-${cache_key}"
  local source_dir=""
  local top_level_entries=0

  echo "Fetching ${repo} ${release_tag}..."

  mkdir -p "${package_dir}" "${extracted_dir}"

  gh release download "${release_tag}" \
    -R "${repo}" \
    -p "${asset_name}" \
    -D "${package_dir}"

  unzip -q "${package_dir}/${asset_name}" -d "${extracted_dir}"

  if [[ -d "${extracted_dir}/${expected_dir}" ]]; then
    source_dir="${extracted_dir}/${expected_dir}"
  else
    top_level_entries="$(find "${extracted_dir}" -mindepth 1 -maxdepth 1 | wc -l | tr -d '[:space:]')"

    if [[ "${top_level_entries}" == "1" ]]; then
      source_dir="$(find "${extracted_dir}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    fi

    if [[ -z "${source_dir}" && -n "${expected_main_file}" && -f "${extracted_dir}/${expected_main_file}" ]]; then
      source_dir="${extracted_dir}"
    fi
  fi

  if [[ -z "${source_dir}" ]]; then
    echo "Invalid package layout for ${asset_name}: expected ${expected_dir}/ or ${expected_main_file}"
    exit 1
  fi

  rm -rf "${target_dir}"
  mkdir -p "$(dirname "${target_dir}")"

  if [[ "${source_dir}" == "${extracted_dir}" ]]; then
    mkdir -p "${target_dir}"
    (
      shopt -s dotglob nullglob
      mv "${extracted_dir}"/* "${target_dir}/"
    )
  else
    mv "${source_dir}" "${target_dir}"
  fi
}

download_repo_archive() {
  local repo="$1"
  local ref="$2"
  local target_dir="$3"
  local cache_key="$4"
  local package_zip="${TMP_DIR}/${cache_key}.zip"
  local extracted_dir="${TMP_DIR}/extracted-${cache_key}"
  local archive_url=""
  local source_dir=""

  echo "Fetching ${repo} ${ref} archive..."

  mkdir -p "${extracted_dir}"

  archive_url="https://github.com/${repo}/archive/refs/tags/${ref}.zip"
  if ! curl -fsSL "${archive_url}" -o "${package_zip}"; then
    archive_url="https://github.com/${repo}/archive/refs/heads/${ref}.zip"
    curl -fsSL "${archive_url}" -o "${package_zip}"
  fi

  unzip -q "${package_zip}" -d "${extracted_dir}"

  source_dir="$(find "${extracted_dir}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [[ -z "${source_dir}" ]]; then
    echo "Invalid archive layout for ${repo} ${ref}"
    exit 1
  fi

  rm -rf "${target_dir}"
  mkdir -p "$(dirname "${target_dir}")"
  mv "${source_dir}" "${target_dir}"
}

download_release_asset "${WORDPRESS_RELEASE_OWNER}/fd-theme" "${FD_THEME_RELEASE_TAG}" "fd-theme.zip" "fd-theme" "${THEMES_DIR}/fd-theme" "fd-theme"
download_release_asset "${WORDPRESS_RELEASE_OWNER}/fd-admin-ui" "${FD_ADMIN_UI_RELEASE_TAG}" "fd-admin-ui.zip" "fd-admin-ui" "${PLUGINS_DIR}/fd-admin-ui" "fd-admin-ui"
download_release_asset "${WORDPRESS_RELEASE_OWNER}/fd-member" "${FD_MEMBER_RELEASE_TAG}" "fd-member.zip" "fd-member" "${PLUGINS_DIR}/fd-member" "fd-member"
download_release_asset "${WORDPRESS_RELEASE_OWNER}/fd-payment" "${FD_PAYMENT_RELEASE_TAG}" "fd-payment.zip" "fd-payment" "${PLUGINS_DIR}/fd-payment" "fd-payment"
download_release_asset "${WORDPRESS_RELEASE_OWNER}/fd-commerce" "${FD_COMMERCE_RELEASE_TAG}" "fd-commerce.zip" "fd-commerce" "${PLUGINS_DIR}/fd-commerce" "fd-commerce"
download_release_asset "${WORDPRESS_RELEASE_OWNER}/fd-content-types" "${FD_CONTENT_TYPES_RELEASE_TAG}" "fd-content-types.zip" "fd-content-types" "${PLUGINS_DIR}/fd-content-types" "fd-content-types"
download_release_asset "${WORDPRESS_RELEASE_OWNER}/fd-websocket-push" "${FD_WEBSOCKET_PUSH_RELEASE_TAG}" "fd-websocket-push.zip" "fd-websocket-push" "${PLUGINS_DIR}/fd-websocket-push" "fd-websocket-push"
download_release_asset "wp-graphql/wp-graphql-jwt-authentication" "${WPGRAPHQL_JWT_AUTH_RELEASE_TAG}" "wp-graphql-jwt-authentication.zip" "wp-graphql-jwt-authentication" "${PLUGINS_DIR}/wp-graphql-jwt-authentication" "wp-graphql-jwt-authentication" "wp-graphql-jwt-authentication.php"
download_repo_archive "wp-graphql/wp-graphql-tax-query" "${WPGRAPHQL_TAX_QUERY_REF}" "${PLUGINS_DIR}/wp-graphql-tax-query-develop" "wp-graphql-tax-query-develop"

desired_assets_lock > "${LOCK_FILE}"

echo "WordPress release assets are ready under ${ROOT_DIR}/runtime/wp-content"
