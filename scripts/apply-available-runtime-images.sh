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

load_env_file "${ENV_FILE}"

NEXT_FRONTEND_IMAGE="${AVAILABLE_FRONTEND_IMAGE:-}"
NEXT_WEBSOCKET_IMAGE="${AVAILABLE_WEBSOCKET_IMAGE:-}"

if [[ -z "${NEXT_FRONTEND_IMAGE}" && -z "${NEXT_WEBSOCKET_IMAGE}" ]]; then
  echo "No available runtime images recorded."
  exit 1
fi

ENV_FILE="${ENV_FILE}" \
FRONTEND_IMAGE="${NEXT_FRONTEND_IMAGE}" \
WEBSOCKET_IMAGE="${NEXT_WEBSOCKET_IMAGE}" \
bash "${ROOT_DIR}/scripts/update-runtime-images.sh"

echo "Applied available runtime images. Run bash scripts/update-stack.sh to pull and recreate containers."
