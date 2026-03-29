#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/common.sh"

if ! command -v openssl >/dev/null 2>&1; then
  echo "Missing required command: openssl"
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/bootstrap-env.sh"
fi

load_env_file "${ENV_FILE}"

generate_secret() {
  openssl rand -hex 32
}

is_placeholder_domain() {
  local value="$1"
  [[ -z "${value}" || "${value}" == "www.example.com" || "${value}" == "admin.example.com" || "${value}" == "ws.example.com" ]]
}

is_placeholder_email() {
  local value="$1"
  [[ -z "${value}" || "${value}" == "admin@example.com" ]]
}

is_placeholder_secret() {
  local value="$1"
  [[ -z "${value}" || "${value}" == CHANGE_ME* ]]
}

normalize_bool() {
  local value="$1"

  value="$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]')"

  case "${value}" in
    y|yes|true|1)
      printf 'true\n'
      ;;
    n|no|false|0)
      printf 'false\n'
      ;;
    *)
      return 1
      ;;
  esac
}

guess_base_domain() {
  local frontend="${FRONTEND_DOMAIN:-}"
  local admin="${ADMIN_DOMAIN:-}"
  local ws="${WS_DOMAIN:-}"
  local suffix=""

  if [[ "${frontend}" == www.* && "${admin}" == admin.* && "${ws}" == ws.* ]]; then
    suffix="${frontend#www.}"
    if [[ "${admin#admin.}" == "${suffix}" && "${ws#ws.}" == "${suffix}" ]]; then
      printf '%s\n' "${suffix}"
      return 0
    fi
  fi

  return 1
}

prompt_value() {
  local prompt="$1"
  local current="$2"
  local reply=""

  if [[ -n "${current}" ]]; then
    printf '%s [%s]: ' "${prompt}" "${current}" >&2
  else
    printf '%s: ' "${prompt}" >&2
  fi

  IFS= read -r reply || true

  if [[ -n "${reply}" ]]; then
    printf '%s\n' "${reply}"
    return 0
  fi

  printf '%s\n' "${current}"
}

prompt_required_value() {
  local prompt="$1"
  local current="$2"
  local value=""

  while true; do
    value="$(prompt_value "${prompt}" "${current}")"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
    echo "这个值不能为空。" >&2
  done
}

prompt_bool() {
  local prompt="$1"
  local current="$2"
  local reply=""
  local default_hint="y/N"
  local normalized=""

  if [[ "${current}" == "true" ]]; then
    default_hint="Y/n"
  fi

  while true; do
    printf '%s [%s]: ' "${prompt}" "${default_hint}" >&2
    IFS= read -r reply || true

    if [[ -z "${reply}" ]]; then
      printf '%s\n' "${current}"
      return 0
    fi

    if normalized="$(normalize_bool "${reply}")"; then
      printf '%s\n' "${normalized}"
      return 0
    fi

    echo "请输入 y 或 n。" >&2
  done
}

ensure_secret_value() {
  local key="$1"
  local current="$2"

  if is_placeholder_secret "${current}"; then
    current="$(generate_secret)"
  fi

  set_env_value "${ENV_FILE}" "${key}" "${current}"
}

fresh_env_guess="false"

if is_placeholder_domain "${FRONTEND_DOMAIN:-}" && \
   is_placeholder_domain "${ADMIN_DOMAIN:-}" && \
   is_placeholder_domain "${WS_DOMAIN:-}" && \
   [[ "${FRONTEND_IMAGE:-}" == *CHANGE_ME* ]] && \
   [[ "${WEBSOCKET_IMAGE:-}" == *CHANGE_ME* ]]; then
  fresh_env_guess="true"
fi

current_base_domain="$(guess_base_domain || true)"
base_domain_default="${current_base_domain}"

if [[ -z "${base_domain_default}" || "${base_domain_default}" == "example.com" ]]; then
  base_domain_default=""
fi

frontend_default="${FRONTEND_DOMAIN:-}"
admin_default="${ADMIN_DOMAIN:-}"
ws_default="${WS_DOMAIN:-}"

if is_placeholder_domain "${frontend_default}"; then
  frontend_default=""
fi

if is_placeholder_domain "${admin_default}"; then
  admin_default=""
fi

if is_placeholder_domain "${ws_default}"; then
  ws_default=""
fi

frontend_image_default="${FRONTEND_IMAGE:-}"
websocket_image_default="${WEBSOCKET_IMAGE:-}"
letsencrypt_email_default="${LETSENCRYPT_EMAIL:-}"
wordpress_release_owner_default="${WORDPRESS_RELEASE_OWNER:-FutureDecade}"
fd_theme_release_tag_default="${FD_THEME_RELEASE_TAG:-v1.0.4}"
fd_admin_ui_release_tag_default="${FD_ADMIN_UI_RELEASE_TAG:-v1.3.1}"
fd_member_release_tag_default="${FD_MEMBER_RELEASE_TAG:-v1.0.1}"
fd_payment_release_tag_default="${FD_PAYMENT_RELEASE_TAG:-v1.0.0}"
fd_commerce_release_tag_default="${FD_COMMERCE_RELEASE_TAG:-v1.0.0}"
fd_websocket_push_release_tag_default="${FD_WEBSOCKET_PUSH_RELEASE_TAG:-v1.0.0}"
wpgraphql_jwt_auth_release_tag_default="${WPGRAPHQL_JWT_AUTH_RELEASE_TAG:-v0.7.2}"
wpgraphql_tax_query_ref_default="${WPGRAPHQL_TAX_QUERY_REF:-v0.2.0}"
wordpress_title_default="${WORDPRESS_TITLE:-FD Headless WP}"
wordpress_admin_user_default="${WORDPRESS_ADMIN_USER:-fdadmin}"
wordpress_admin_password_default="${WORDPRESS_ADMIN_PASSWORD:-}"
wordpress_admin_email_default="${WORDPRESS_ADMIN_EMAIL:-}"

if [[ "${frontend_image_default}" == *CHANGE_ME* ]]; then
  frontend_image_default=""
fi

if [[ "${websocket_image_default}" == *CHANGE_ME* ]]; then
  websocket_image_default=""
fi

if is_placeholder_email "${letsencrypt_email_default}"; then
  letsencrypt_email_default=""
fi

if is_placeholder_secret "${wordpress_admin_password_default}"; then
  wordpress_admin_password_default=""
fi

if is_placeholder_email "${wordpress_admin_email_default}"; then
  wordpress_admin_email_default=""
fi

if wordpress_fetch_release_assets_default="$(normalize_bool "${WORDPRESS_FETCH_RELEASE_ASSETS:-false}" 2>/dev/null)"; then
  :
else
  wordpress_fetch_release_assets_default="false"
fi

if [[ "${fresh_env_guess}" == "true" && "${wordpress_fetch_release_assets_default}" == "false" ]]; then
  wordpress_fetch_release_assets_default="true"
fi

if wordpress_run_init_default="$(normalize_bool "${WORDPRESS_RUN_INIT:-false}" 2>/dev/null)"; then
  :
else
  wordpress_run_init_default="false"
fi

echo
echo "现在开始配置：${ENV_FILE}"
echo "这一步只会修改配置文件，不会启动任何服务。"
echo

base_domain="$(prompt_value "主域名，例如 futuredecade.com" "${base_domain_default}")"

if [[ -n "${base_domain}" ]]; then
  if [[ -z "${frontend_default}" ]]; then
    frontend_default="www.${base_domain}"
  fi
  if [[ -z "${admin_default}" ]]; then
    admin_default="admin.${base_domain}"
  fi
  if [[ -z "${ws_default}" ]]; then
    ws_default="ws.${base_domain}"
  fi
fi

frontend_domain="$(prompt_required_value "前台域名" "${frontend_default}")"
admin_domain="$(prompt_required_value "后台域名" "${admin_default}")"
ws_domain="$(prompt_required_value "推送域名" "${ws_default}")"

frontend_image="$(prompt_required_value "前台镜像完整地址" "${frontend_image_default}")"
websocket_image="$(prompt_required_value "推送镜像完整地址" "${websocket_image_default}")"
letsencrypt_email="$(prompt_required_value "证书通知邮箱" "${letsencrypt_email_default}")"

wordpress_fetch_release_assets="$(prompt_bool "是否自动从 GitHub release 拉主题和插件，推荐 y" "${wordpress_fetch_release_assets_default}")"
wordpress_run_init="$(prompt_bool "是否自动完成首次 WordPress 安装" "${wordpress_run_init_default}")"

set_env_value "${ENV_FILE}" "FRONTEND_DOMAIN" "${frontend_domain}"
set_env_value "${ENV_FILE}" "ADMIN_DOMAIN" "${admin_domain}"
set_env_value "${ENV_FILE}" "WS_DOMAIN" "${ws_domain}"
set_env_value "${ENV_FILE}" "FRONTEND_IMAGE" "${frontend_image}"
set_env_value "${ENV_FILE}" "WEBSOCKET_IMAGE" "${websocket_image}"
set_env_value "${ENV_FILE}" "LETSENCRYPT_EMAIL" "${letsencrypt_email}"
set_env_value "${ENV_FILE}" "PUBLIC_SCHEME" "${PUBLIC_SCHEME:-http}"
set_env_value "${ENV_FILE}" "WEBSOCKET_PUBLIC_SCHEME" "${WEBSOCKET_PUBLIC_SCHEME:-ws}"
set_env_value "${ENV_FILE}" "HTTPS_ENABLED" "${HTTPS_ENABLED:-false}"
set_env_value "${ENV_FILE}" "HTTP_PORT" "${HTTP_PORT:-80}"
set_env_value "${ENV_FILE}" "HTTPS_PORT" "${HTTPS_PORT:-443}"
set_env_value "${ENV_FILE}" "WORDPRESS_FETCH_RELEASE_ASSETS" "${wordpress_fetch_release_assets}"
set_env_value "${ENV_FILE}" "WORDPRESS_RUN_INIT" "${wordpress_run_init}"

ensure_secret_value "MYSQL_PASSWORD" "${MYSQL_PASSWORD:-}"
ensure_secret_value "MYSQL_ROOT_PASSWORD" "${MYSQL_ROOT_PASSWORD:-}"
ensure_secret_value "JWT_SECRET" "${JWT_SECRET:-}"
ensure_secret_value "PUSH_SECRET" "${PUSH_SECRET:-}"
ensure_secret_value "REVALIDATE_SECRET" "${REVALIDATE_SECRET:-}"

if [[ "${wordpress_fetch_release_assets}" == "true" ]]; then
  wordpress_release_owner="$(prompt_required_value "GitHub 发布账号或组织" "${wordpress_release_owner_default}")"
  fd_theme_release_tag="$(prompt_required_value "fd-theme release tag" "${fd_theme_release_tag_default}")"
  fd_admin_ui_release_tag="$(prompt_required_value "fd-admin-ui release tag" "${fd_admin_ui_release_tag_default}")"
  fd_member_release_tag="$(prompt_required_value "fd-member release tag" "${fd_member_release_tag_default}")"
  fd_payment_release_tag="$(prompt_required_value "fd-payment release tag" "${fd_payment_release_tag_default}")"
  fd_commerce_release_tag="$(prompt_required_value "fd-commerce release tag" "${fd_commerce_release_tag_default}")"
  fd_websocket_push_release_tag="$(prompt_required_value "fd-websocket-push release tag" "${fd_websocket_push_release_tag_default}")"
  wpgraphql_jwt_auth_release_tag="$(prompt_required_value "wp-graphql-jwt-authentication release tag" "${wpgraphql_jwt_auth_release_tag_default}")"
  wpgraphql_tax_query_ref="$(prompt_required_value "wp-graphql-tax-query ref" "${wpgraphql_tax_query_ref_default}")"

  set_env_value "${ENV_FILE}" "WORDPRESS_RELEASE_OWNER" "${wordpress_release_owner}"
  set_env_value "${ENV_FILE}" "FD_THEME_RELEASE_TAG" "${fd_theme_release_tag}"
  set_env_value "${ENV_FILE}" "FD_ADMIN_UI_RELEASE_TAG" "${fd_admin_ui_release_tag}"
  set_env_value "${ENV_FILE}" "FD_MEMBER_RELEASE_TAG" "${fd_member_release_tag}"
  set_env_value "${ENV_FILE}" "FD_PAYMENT_RELEASE_TAG" "${fd_payment_release_tag}"
  set_env_value "${ENV_FILE}" "FD_COMMERCE_RELEASE_TAG" "${fd_commerce_release_tag}"
  set_env_value "${ENV_FILE}" "FD_WEBSOCKET_PUSH_RELEASE_TAG" "${fd_websocket_push_release_tag}"
  set_env_value "${ENV_FILE}" "WPGRAPHQL_JWT_AUTH_RELEASE_TAG" "${wpgraphql_jwt_auth_release_tag}"
  set_env_value "${ENV_FILE}" "WPGRAPHQL_TAX_QUERY_REF" "${wpgraphql_tax_query_ref}"
fi

if [[ "${wordpress_run_init}" == "true" ]]; then
  if [[ -z "${wordpress_admin_email_default}" ]]; then
    wordpress_admin_email_default="${letsencrypt_email}"
  fi

  wordpress_title="$(prompt_required_value "WordPress 站点标题" "${wordpress_title_default}")"
  wordpress_admin_user="$(prompt_required_value "WordPress 管理员用户名" "${wordpress_admin_user_default}")"
  wordpress_admin_password="$(prompt_required_value "WordPress 管理员密码" "${wordpress_admin_password_default}")"
  wordpress_admin_email="$(prompt_required_value "WordPress 管理员邮箱" "${wordpress_admin_email_default}")"

  set_env_value "${ENV_FILE}" "WORDPRESS_TITLE" "${wordpress_title}"
  set_env_value "${ENV_FILE}" "WORDPRESS_ADMIN_USER" "${wordpress_admin_user}"
  set_env_value "${ENV_FILE}" "WORDPRESS_ADMIN_PASSWORD" "${wordpress_admin_password}"
  set_env_value "${ENV_FILE}" "WORDPRESS_ADMIN_EMAIL" "${wordpress_admin_email}"
fi

echo
echo "配置已经写入：${ENV_FILE}"
echo
echo "建议下一步："
echo "1. 如果要拉 GitHub release 主题和插件，先运行：gh auth login"
echo "2. 如果前端和推送镜像在私有 ACR，先运行 docker login"
echo "3. 运行：bash scripts/preflight-check.sh"
echo "4. 首次启动：bash scripts/install.sh"
echo "5. 确认 HTTP 正常后，再运行：bash scripts/setup-https.sh"
