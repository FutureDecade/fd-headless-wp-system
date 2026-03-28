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

legacy_image_for_key() {
  case "$1" in
    MARIADB_IMAGE) printf '%s\n' "mariadb:10.11" ;;
    REDIS_IMAGE) printf '%s\n' "redis:7" ;;
    WORDPRESS_IMAGE) printf '%s\n' "wordpress:6.8.3-php8.2-apache" ;;
    WPCLI_IMAGE) printf '%s\n' "wordpress:cli-2.12.0" ;;
    NGINX_IMAGE) printf '%s\n' "nginx:1.27-alpine" ;;
    CERTBOT_IMAGE) printf '%s\n' "certbot/certbot:latest" ;;
    *)
      echo "Unsupported image key: $1" >&2
      exit 1
      ;;
  esac
}

acr_image_for_key() {
  case "$1" in
    MARIADB_IMAGE) printf '%s\n' "crpi-8y82lbqoc1haiday.cn-beijing.personal.cr.aliyuncs.com/futuredecade/runtime-mariadb:10.11" ;;
    REDIS_IMAGE) printf '%s\n' "crpi-8y82lbqoc1haiday.cn-beijing.personal.cr.aliyuncs.com/futuredecade/runtime-redis:7" ;;
    WORDPRESS_IMAGE) printf '%s\n' "crpi-8y82lbqoc1haiday.cn-beijing.personal.cr.aliyuncs.com/futuredecade/runtime-wordpress:6.8.3-php8.2-apache" ;;
    WPCLI_IMAGE) printf '%s\n' "crpi-8y82lbqoc1haiday.cn-beijing.personal.cr.aliyuncs.com/futuredecade/runtime-wpcli:cli-2.12.0" ;;
    NGINX_IMAGE) printf '%s\n' "crpi-8y82lbqoc1haiday.cn-beijing.personal.cr.aliyuncs.com/futuredecade/runtime-nginx:1.27-alpine" ;;
    CERTBOT_IMAGE) printf '%s\n' "crpi-8y82lbqoc1haiday.cn-beijing.personal.cr.aliyuncs.com/futuredecade/runtime-certbot:latest" ;;
    *)
      echo "Unsupported image key: $1" >&2
      exit 1
      ;;
  esac
}

load_env_file "${ENV_FILE}"

updated_any=false

for key in MARIADB_IMAGE REDIS_IMAGE WORDPRESS_IMAGE WPCLI_IMAGE NGINX_IMAGE CERTBOT_IMAGE; do
  current_value="${!key:-}"
  target_value="$(acr_image_for_key "${key}")"
  legacy_value="$(legacy_image_for_key "${key}")"

  if [[ -z "${current_value}" || "${current_value}" == "${legacy_value}" ]]; then
    if [[ "${current_value}" != "${target_value}" ]]; then
      set_env_value "${ENV_FILE}" "${key}" "${target_value}"
      echo "Updated ${key} -> ${target_value}"
      updated_any=true
    fi
  fi
done

if [[ "${updated_any}" == "false" ]]; then
  echo "Base image settings already use custom values. No migration needed."
fi
