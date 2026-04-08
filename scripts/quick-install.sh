#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/common.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/stack-bootstrap.sh"

prompt_value() {
  local prompt="$1"
  local current="${2:-}"
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
  local current="${2:-}"
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

prompt_secret() {
  local prompt="$1"
  local current="${2:-}"
  local reply=""

  if [[ -n "${current}" ]]; then
    printf '%s [已存在，直接回车可继续使用]: ' "${prompt}" >&2
  else
    printf '%s: ' "${prompt}" >&2
  fi

  IFS= read -r -s reply || true
  printf '\n' >&2

  if [[ -n "${reply}" ]]; then
    printf '%s\n' "${reply}"
    return 0
  fi

  printf '%s\n' "${current}"
}

prompt_yes_no() {
  local prompt="$1"
  local default_value="${2:-y}"
  local reply=""

  if [[ "${default_value}" == "y" ]]; then
    printf '%s [Y/n]: ' "${prompt}" >&2
  else
    printf '%s [y/N]: ' "${prompt}" >&2
  fi

  IFS= read -r reply || true

  if [[ -z "${reply}" ]]; then
    reply="${default_value}"
  fi

  reply="$(printf '%s' "${reply}" | tr '[:upper:]' '[:lower:]')"

  case "${reply}" in
    y|yes)
      printf 'yes\n'
      ;;
    n|no)
      printf 'no\n'
      ;;
    *)
      echo "请输入 y 或 n。" >&2
      return 1
      ;;
  esac
}

remove_persisted_delivery_credentials() {
  unset_env_keys "${ENV_FILE}" \
    "ACR_USERNAME" \
    "ACR_PASSWORD" \
    "GH_TOKEN" \
    "GITHUB_TOKEN"
}

cleanup_bootstrap_state() {
  if [[ "${stack_bootstrap_mode:-false}" == "true" ]]; then
    remove_persisted_delivery_credentials
  fi

  unset FD_STACK_BOOTSTRAP_JSON FD_STACK_DEPLOY_TOKEN FD_STACK_EXCHANGE_URL FD_STACK_PUBLIC_BASE_URL
  unset ACR_USERNAME ACR_PASSWORD GH_TOKEN GITHUB_TOKEN
}

detect_registry_host() {
  local image="$1"

  if [[ "${image}" != */* ]]; then
    return 1
  fi

  local first_segment="${image%%/*}"
  if [[ "${first_segment}" == *.* || "${first_segment}" == *:* || "${first_segment}" == "localhost" ]]; then
    printf '%s\n' "${first_segment}"
    return 0
  fi

  return 1
}

needs_acr_credentials() {
  local image=""
  local registry=""

  for image in \
    "${MARIADB_IMAGE:-}" \
    "${REDIS_IMAGE:-}" \
    "${WORDPRESS_IMAGE:-}" \
    "${FRONTEND_IMAGE:-}" \
    "${WEBSOCKET_IMAGE:-}" \
    "${NGINX_IMAGE:-}" \
    "${WPCLI_IMAGE:-}" \
    "${CERTBOT_IMAGE:-}"; do
    registry="$(detect_registry_host "${image}" || true)"
    if [[ -n "${registry}" && "${registry}" == *.aliyuncs.com ]]; then
      return 0
    fi
  done

  return 1
}

collect_acr_credentials() {
  if ! needs_acr_credentials; then
    return 0
  fi

  echo
  echo "检测到这套配置会从阿里云 ACR 拉镜像。"
  ACR_USERNAME="${ACR_USERNAME:-$(prompt_required_value "阿里云 ACR 用户名")}"
  ACR_PASSWORD="${ACR_PASSWORD:-$(prompt_secret "阿里云 ACR 密码")}"
  export ACR_USERNAME
  export ACR_PASSWORD
}

collect_github_token_if_needed() {
  if [[ "${WORDPRESS_FETCH_RELEASE_ASSETS:-false}" != "true" ]]; then
    return 0
  fi

  if [[ -n "${GH_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
    return 0
  fi

  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    return 0
  fi

  echo
  echo "检测到这套配置需要从 GitHub Release 拉 WordPress 主题和插件。"
  GH_TOKEN="$(prompt_secret "GitHub token")"
  export GH_TOKEN
}

is_placeholder_email() {
  local value="$1"
  [[ -z "${value}" || "${value}" == "admin@example.com" ]]
}

auto_https_enabled() {
  if [[ "${stack_bootstrap_mode}" != "true" ]]; then
    return 1
  fi

  if is_placeholder_email "${LETSENCRYPT_EMAIL:-}"; then
    return 1
  fi

  if [[ -z "${FRONTEND_DOMAIN:-}" || -z "${ADMIN_DOMAIN:-}" || -z "${WS_DOMAIN:-}" ]]; then
    return 1
  fi

  return 0
}

print_final_summary() {
  load_env_file "${ENV_FILE}"

  echo
  echo "部署完成。"
  echo "前台地址：${PUBLIC_SCHEME:-http}://${FRONTEND_DOMAIN}"
  echo "后台地址：${PUBLIC_SCHEME:-http}://${ADMIN_DOMAIN}"
  echo "推送健康检查：${WEBSOCKET_PUBLIC_SCHEME:-ws}://${WS_DOMAIN}/health"

  if [[ "${WORDPRESS_RUN_INIT:-false}" == "true" ]]; then
    echo "WordPress 管理员用户名：${WORDPRESS_ADMIN_USER}"
    echo "WordPress 管理员密码：出于安全原因不在终端回显。"
    echo "WordPress 管理员邮箱：${WORDPRESS_ADMIN_EMAIL}"
  fi
}

stack_bootstrap_mode="false"

echo
echo "这一步会按顺序做 3 件事："
echo "1. 生成或更新 .env"
echo "2. 收集首次安装需要的凭据"
echo "3. 调用已经验证过的 install.sh 完成首装"

if [[ -n "${FD_STACK_BOOTSTRAP_JSON:-}" || -n "${FD_STACK_DEPLOY_TOKEN:-}" ]]; then
  stack_bootstrap_mode="true"
  if ! load_stack_bootstrap; then
    echo "FD Stack 部署预设加载失败，安装已停止。"
    exit 1
  fi

  echo
  echo "已从 FD Stack deploy token 载入部署预设。"
  echo "安装目录：${INSTALL_DIR:-${ROOT_DIR}}"
  echo "前台域名预设：${FRONTEND_DOMAIN:-未提供}"
  echo "后台域名预设：${ADMIN_DOMAIN:-未提供}"
  echo "推送域名预设：${WS_DOMAIN:-未提供}"
fi

if [[ "${stack_bootstrap_mode}" == "true" ]]; then
  trap cleanup_bootstrap_state EXIT
fi

echo
echo "先进入配置向导。"
ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/configure-env.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "配置文件不存在：${ENV_FILE}"
  exit 1
fi

if [[ "${stack_bootstrap_mode}" == "true" ]]; then
  remove_persisted_delivery_credentials
fi

load_env_file "${ENV_FILE}"
collect_acr_credentials
collect_github_token_if_needed

echo
echo "即将开始首次安装。"
echo "目标前台域名：${FRONTEND_DOMAIN:-未设置}"
echo "目标后台域名：${ADMIN_DOMAIN:-未设置}"
echo "目标推送域名：${WS_DOMAIN:-未设置}"

if [[ "${stack_bootstrap_mode}" != "true" ]]; then
  while true; do
    if [[ "$(prompt_yes_no "现在开始安装" "y")" == "yes" ]]; then
      break
    fi
    echo "已取消安装。配置已保留在 ${ENV_FILE}"
    exit 0
  done
fi

ENV_FILE="${ENV_FILE}" \
ACR_USERNAME="${ACR_USERNAME:-}" \
ACR_PASSWORD="${ACR_PASSWORD:-}" \
GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" \
GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}" \
bash "${ROOT_DIR}/scripts/install.sh"

echo
if auto_https_enabled; then
  echo "HTTP 首装完成，开始自动申请证书并切换 HTTPS..."
  ENV_FILE="${ENV_FILE}" \
  ACR_USERNAME="${ACR_USERNAME:-}" \
  ACR_PASSWORD="${ACR_PASSWORD:-}" \
  GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" \
  GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}" \
  bash "${ROOT_DIR}/scripts/setup-https.sh"
fi

echo "首装入口执行完成。"

if [[ "${stack_bootstrap_mode}" == "true" ]]; then
  print_final_summary
else
  echo "下一步请先检查 HTTP 是否正常。"
  echo "确认正常后，再运行：bash ${ROOT_DIR}/scripts/quick-setup-https.sh"
fi
