#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/common.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env file. Run: cp .env.example .env"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is not available. Skipping pending deployment action runner."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is not available. Skipping pending deployment action runner."
  exit 0
fi

load_env_file "${ENV_FILE}"

if [[ -z "${FD_STACK_DEPLOYMENT_ID:-}" || -z "${FD_STACK_STATUS_REPORT_TOKEN:-}" || -z "${FD_STACK_ACTION_PULL_URL:-}" || -z "${FD_STACK_ACTION_COMPLETE_URL:-}" ]]; then
  echo "FD Stack action polling is not configured. Skipping pending deployment action runner."
  exit 0
fi

pull_payload="$(
  jq -n \
    --arg deploymentId "${FD_STACK_DEPLOYMENT_ID}" \
    --arg token "${FD_STACK_STATUS_REPORT_TOKEN}" \
    '{deploymentId: $deploymentId, token: $token}'
)"

response="$(curl -fsSL -X POST "${FD_STACK_ACTION_PULL_URL}" \
  -H 'content-type: application/json' \
  -d "${pull_payload}")"

action_id="$(printf '%s' "${response}" | jq -r '.action.id // empty')"
action_kind="$(printf '%s' "${response}" | jq -r '.action.kind // empty')"

if [[ -z "${action_id}" || -z "${action_kind}" ]]; then
  echo "No pending deployment action."
  exit 0
fi

status="completed"
message=""

if [[ "${action_kind}" == "apply_runtime_images" ]]; then
  if ! (
    ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/apply-available-runtime-images.sh" &&
    ENV_FILE="${ENV_FILE}" SKIP_IMAGE_PULL="${SKIP_IMAGE_PULL:-false}" ACR_USERNAME="${ACR_USERNAME:-}" ACR_PASSWORD="${ACR_PASSWORD:-}" bash "${ROOT_DIR}/scripts/update-runtime-services.sh"
  ); then
    status="failed"
    message="Failed to apply runtime image update"
  fi
elif [[ "${action_kind}" == "apply_wordpress_assets" ]]; then
  if ! (
    ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/apply-available-wordpress-release-tags.sh" &&
    ENV_FILE="${ENV_FILE}" FORCE_WORDPRESS_ASSET_FETCH=true SKIP_IMAGE_PULL="${SKIP_IMAGE_PULL:-false}" ACR_USERNAME="${ACR_USERNAME:-}" ACR_PASSWORD="${ACR_PASSWORD:-}" GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}" bash "${ROOT_DIR}/scripts/update-stack.sh"
  ); then
    status="failed"
    message="Failed to apply WordPress asset update"
  fi
elif [[ "${action_kind}" == "ignore_runtime_images" ]]; then
  if ! ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/clear-available-runtime-images.sh"; then
    status="failed"
    message="Failed to ignore runtime image update"
  fi
elif [[ "${action_kind}" == "ignore_wordpress_assets" ]]; then
  if ! ENV_FILE="${ENV_FILE}" bash "${ROOT_DIR}/scripts/clear-available-wordpress-release-tags.sh"; then
    status="failed"
    message="Failed to ignore WordPress asset update"
  fi
else
  status="failed"
  message="Unknown deployment action kind: ${action_kind}"
fi

complete_payload="$(
  jq -n \
    --arg deploymentId "${FD_STACK_DEPLOYMENT_ID}" \
    --arg token "${FD_STACK_STATUS_REPORT_TOKEN}" \
    --arg actionId "${action_id}" \
    --arg status "${status}" \
    --arg message "${message}" \
    '{
      deploymentId: $deploymentId,
      token: $token,
      actionId: $actionId,
      status: $status,
      message: ($message | select(length > 0))
    }'
)"

curl -fsSL -X POST "${FD_STACK_ACTION_COMPLETE_URL}" \
  -H 'content-type: application/json' \
  -d "${complete_payload}" >/dev/null

echo "Deployment action ${action_id} finished with status: ${status}"
