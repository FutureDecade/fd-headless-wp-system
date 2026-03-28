#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/fd-headless-wp-system}"
REPO_URL="${REPO_URL:-https://github.com/FutureDecade/fd-headless-wp-system.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"

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
  run_root_cmd apt-get install -y git curl ca-certificates
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
echo "HTTPS 切换入口开始。"
echo "目标目录：${INSTALL_DIR}"

ensure_minimal_packages
clone_or_update_repo

run_root_cmd bash "${INSTALL_DIR}/scripts/quick-setup-https.sh"
