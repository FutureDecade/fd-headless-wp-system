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
FD_THEME_RELEASE_TAG="${FD_THEME_RELEASE_TAG:-v1.0.0}"
FD_MEMBER_RELEASE_TAG="${FD_MEMBER_RELEASE_TAG:-v1.0.0}"
FD_PAYMENT_RELEASE_TAG="${FD_PAYMENT_RELEASE_TAG:-v1.0.0}"
FD_COMMERCE_RELEASE_TAG="${FD_COMMERCE_RELEASE_TAG:-v1.0.0}"

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
fd-member=${FD_MEMBER_RELEASE_TAG}
fd-payment=${FD_PAYMENT_RELEASE_TAG}
fd-commerce=${FD_COMMERCE_RELEASE_TAG}
EOF
}

assets_already_match() {
  if [[ ! -f "${LOCK_FILE}" ]]; then
    return 1
  fi

  if [[ ! -d "${THEMES_DIR}/fd-theme" ]]; then
    return 1
  fi

  for plugin_dir in fd-member fd-payment fd-commerce; do
    if [[ ! -d "${PLUGINS_DIR}/${plugin_dir}" ]]; then
      return 1
    fi
  done

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

if [[ -z "${GH_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

download_and_extract() {
  local slug="$1"
  local release_tag="$2"
  local repo="${WORDPRESS_RELEASE_OWNER}/${slug}"
  local asset_name="${slug}.zip"
  local package_dir="${TMP_DIR}/${slug}"
  local extracted_dir="${TMP_DIR}/extracted-${slug}"
  local target_dir="$3"

  echo "Fetching ${repo} ${release_tag}..."

  mkdir -p "${package_dir}" "${extracted_dir}"

  gh release download "${release_tag}" \
    -R "${repo}" \
    -p "${asset_name}" \
    -D "${package_dir}"

  unzip -q "${package_dir}/${asset_name}" -d "${extracted_dir}"

  if [[ ! -d "${extracted_dir}/${slug}" ]]; then
    echo "Invalid package layout for ${asset_name}: missing ${slug}/"
    exit 1
  fi

  rm -rf "${target_dir}"
  mkdir -p "$(dirname "${target_dir}")"
  mv "${extracted_dir}/${slug}" "${target_dir}"
}

download_and_extract "fd-theme" "${FD_THEME_RELEASE_TAG}" "${THEMES_DIR}/fd-theme"
download_and_extract "fd-member" "${FD_MEMBER_RELEASE_TAG}" "${PLUGINS_DIR}/fd-member"
download_and_extract "fd-payment" "${FD_PAYMENT_RELEASE_TAG}" "${PLUGINS_DIR}/fd-payment"
download_and_extract "fd-commerce" "${FD_COMMERCE_RELEASE_TAG}" "${PLUGINS_DIR}/fd-commerce"

desired_assets_lock > "${LOCK_FILE}"

echo "WordPress release assets are ready under ${ROOT_DIR}/runtime/wp-content"
