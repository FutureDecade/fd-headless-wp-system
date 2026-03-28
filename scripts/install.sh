#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
  bash "${ROOT_DIR}/scripts/bootstrap-env.sh"

  echo
  echo "已经帮你生成配置文件：${ENV_FILE}"
  echo "首次部署前，请先把这些值改成你自己的："
  echo "- FRONTEND_DOMAIN"
  echo "- ADMIN_DOMAIN"
  echo "- WS_DOMAIN"
  echo "- FRONTEND_IMAGE"
  echo "- WEBSOCKET_IMAGE"
  echo "- MYSQL_PASSWORD"
  echo "- MYSQL_ROOT_PASSWORD"
  echo "- JWT_SECRET"
  echo "- PUSH_SECRET"
  echo "- REVALIDATE_SECRET"
  echo
  echo "改完后，再重新运行这条命令即可。"
  exit 1
fi

echo "Running preflight check..."
ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/preflight-check.sh"

echo "Starting first install through the verified safe update flow..."
ENV_FILE="${ENV_FILE}" \
ACR_USERNAME="${ACR_USERNAME:-}" \
ACR_PASSWORD="${ACR_PASSWORD:-}" \
GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" \
GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}" \
FORCE_WORDPRESS_ASSET_FETCH="${FORCE_WORDPRESS_ASSET_FETCH:-false}" \
bash "${ROOT_DIR}/scripts/update-stack.sh"

echo
echo "Bootstrap install finished."
echo "First install completed through the same path used for later updates."
