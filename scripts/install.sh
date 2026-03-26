#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  bash "${ROOT_DIR}/scripts/bootstrap-env.sh"
fi

bash "${ROOT_DIR}/scripts/preflight-check.sh"

echo "Starting services..."
docker compose --env-file "${ROOT_DIR}/.env" up -d

echo
echo "Bootstrap install finished."
echo "This is an early delivery scaffold, not the final production installer."
