#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR_WAS_SET="${INSTALL_DIR+x}"
REPO_URL_WAS_SET="${REPO_URL+x}"
REPO_BRANCH_WAS_SET="${REPO_BRANCH+x}"
INSTALL_DIR="${INSTALL_DIR:-/opt/fd-headless-wp-system}"
REPO_URL="${REPO_URL:-https://github.com/FutureDecade/fd-headless-wp-system.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
FD_STACK_BOOTSTRAP_JSON="${FD_STACK_BOOTSTRAP_JSON:-}"

run_root_cmd() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "这个脚本需要 root 权限。请使用 root 运行，或者先安装 sudo。"
    exit 1
  fi

  sudo "$@"
}

ensure_minimal_packages() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "当前系统没有 apt-get。这个脚本目前只支持 Debian / Ubuntu。"
    exit 1
  fi

  run_root_cmd apt-get update
  run_root_cmd apt-get install -y git curl ca-certificates jq
}

resolve_stack_exchange_url() {
  if [[ -n "${FD_STACK_EXCHANGE_URL:-}" ]]; then
    printf '%s\n' "${FD_STACK_EXCHANGE_URL}"
    return 0
  fi

  if [[ -n "${FD_STACK_PUBLIC_BASE_URL:-}" ]]; then
    printf '%s/v1/deployments/bootstrap/exchange\n' "${FD_STACK_PUBLIC_BASE_URL%/}"
    return 0
  fi

  return 1
}

apply_stack_bootstrap_defaults() {
  local bootstrap_json="$1"
  local install_path=""
  local repo_url=""
  local repo_branch=""

  FD_STACK_BOOTSTRAP_JSON="${bootstrap_json}"
  export FD_STACK_BOOTSTRAP_JSON

  install_path="$(printf '%s' "${bootstrap_json}" | jq -r '.bootstrap.installPath // empty')"
  repo_url="$(printf '%s' "${bootstrap_json}" | jq -r '.bootstrap.repository.url // empty')"
  repo_branch="$(printf '%s' "${bootstrap_json}" | jq -r '.bootstrap.repository.branch // empty')"

  if [[ -n "${install_path}" && -z "${INSTALL_DIR_WAS_SET:-}" ]]; then
    INSTALL_DIR="${install_path}"
    export INSTALL_DIR
  fi

  if [[ -n "${repo_url}" && -z "${REPO_URL_WAS_SET:-}" ]]; then
    REPO_URL="${repo_url}"
    export REPO_URL
  fi

  if [[ -n "${repo_branch}" && -z "${REPO_BRANCH_WAS_SET:-}" ]]; then
    REPO_BRANCH="${repo_branch}"
    export REPO_BRANCH
  fi
}

exchange_stack_bootstrap_if_needed() {
  local exchange_url=""
  local response=""
  local curl_stderr=""

  if [[ -z "${FD_STACK_DEPLOY_TOKEN:-}" ]]; then
    return 0
  fi

  if ! exchange_url="$(resolve_stack_exchange_url)"; then
    echo "检测到 FD_STACK_DEPLOY_TOKEN，但没有提供 FD_STACK_EXCHANGE_URL 或 FD_STACK_PUBLIC_BASE_URL。"
    exit 1
  fi

  echo "检测到 FD Stack deploy token，正在拉取部署预设..."
  curl_stderr="$(mktemp)"
  if ! response="$(
    curl -fsSL -X POST "${exchange_url}" \
      -H 'content-type: application/json' \
      -d "{\"token\":\"${FD_STACK_DEPLOY_TOKEN}\"}" \
      2>"${curl_stderr}"
  )"; then
    echo "FD Stack 部署预设拉取失败，安装已停止。请检查 deploy token 是否有效或是否已过期。" >&2
    if [[ -s "${curl_stderr}" ]]; then
      cat "${curl_stderr}" >&2
    fi
    rm -f "${curl_stderr}"
    exit 1
  fi
  rm -f "${curl_stderr}"

  apply_stack_bootstrap_defaults "${response}"
}

repo_is_dirty() {
  local repo_dir="$1"

  if ! run_root_cmd git -C "${repo_dir}" diff --quiet; then
    return 0
  fi

  if ! run_root_cmd git -C "${repo_dir}" diff --cached --quiet; then
    return 0
  fi

  if [[ -n "$(run_root_cmd git -C "${repo_dir}" ls-files --others --exclude-standard)" ]]; then
    return 0
  fi

  return 1
}

clone_or_update_repo() {
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    local current_branch=""
    current_branch="$(run_root_cmd git -C "${INSTALL_DIR}" branch --show-current 2>/dev/null || true)"

    if [[ -n "${current_branch}" && "${current_branch}" != "${REPO_BRANCH}" ]]; then
      echo "现有仓库分支不是 ${REPO_BRANCH}，为避免误操作，这里先停止。"
      echo "当前分支：${current_branch}"
      exit 1
    fi

    if repo_is_dirty "${INSTALL_DIR}"; then
      echo "现有交付仓库目录有未提交改动：${INSTALL_DIR}"
      echo "为避免覆盖你的本地改动，这里先停止。"
      exit 1
    fi

    run_root_cmd git -C "${INSTALL_DIR}" pull --ff-only origin "${REPO_BRANCH}"
    return 0
  fi

  if [[ -e "${INSTALL_DIR}" ]]; then
    echo "目标目录已存在但不是 git 仓库：${INSTALL_DIR}"
    echo "请先手工处理这个目录，再重新运行。"
    exit 1
  fi

  run_root_cmd mkdir -p "$(dirname "${INSTALL_DIR}")"
  run_root_cmd git clone --branch "${REPO_BRANCH}" --depth 1 "${REPO_URL}" "${INSTALL_DIR}"
}

echo
echo "空白服务器首装入口开始。"

ensure_minimal_packages
exchange_stack_bootstrap_if_needed
echo "目标目录：${INSTALL_DIR}"
clone_or_update_repo

run_root_cmd bash "${INSTALL_DIR}/scripts/prepare-server.sh"
run_root_cmd env \
  FD_STACK_BOOTSTRAP_JSON="${FD_STACK_BOOTSTRAP_JSON:-}" \
  FD_STACK_DEPLOY_TOKEN="${FD_STACK_DEPLOY_TOKEN:-}" \
  FD_STACK_EXCHANGE_URL="${FD_STACK_EXCHANGE_URL:-}" \
  FD_STACK_PUBLIC_BASE_URL="${FD_STACK_PUBLIC_BASE_URL:-}" \
  INSTALL_DIR="${INSTALL_DIR}" \
  REPO_URL="${REPO_URL}" \
  REPO_BRANCH="${REPO_BRANCH}" \
  bash "${INSTALL_DIR}/scripts/quick-install.sh"
