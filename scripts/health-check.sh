#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/common.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env file. Skip deployment health check."
  exit 0
fi

load_env_file "${ENV_FILE}"

DEPLOYMENT_HEALTH_CHECK_ENABLED="${DEPLOYMENT_HEALTH_CHECK_ENABLED:-true}"
DEPLOYMENT_HEALTH_TIMEOUT_SECONDS="${DEPLOYMENT_HEALTH_TIMEOUT_SECONDS:-20}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_ENABLED="${HTTPS_ENABLED:-false}"
HTTPS_PORT="${HTTPS_PORT:-443}"

if [[ "${DEPLOYMENT_HEALTH_CHECK_ENABLED}" != "true" ]]; then
  echo "DEPLOYMENT_HEALTH_CHECK_ENABLED=false, skipping deployment health check."
  exit 0
fi

if [[ -z "${FRONTEND_DOMAIN:-}" || -z "${ADMIN_DOMAIN:-}" || -z "${WS_DOMAIN:-}" ]]; then
  echo "FRONTEND_DOMAIN, ADMIN_DOMAIN or WS_DOMAIN is missing. Skip deployment health check."
  exit 0
fi

tmp_health="$(mktemp)"

cleanup() {
  rm -f "${tmp_health}"
}
trap cleanup EXIT

curl_frontend() {
  local path="$1"
  shift

  if [[ "${HTTPS_ENABLED}" == "true" ]]; then
    curl -ksS \
      --resolve "${FRONTEND_DOMAIN}:${HTTPS_PORT}:127.0.0.1" \
      --max-time "${DEPLOYMENT_HEALTH_TIMEOUT_SECONDS}" \
      "$@" \
      "https://${FRONTEND_DOMAIN}:${HTTPS_PORT}${path}"
  else
    curl -sS \
      -H "Host: ${FRONTEND_DOMAIN}" \
      --max-time "${DEPLOYMENT_HEALTH_TIMEOUT_SECONDS}" \
      "$@" \
      "http://127.0.0.1:${HTTP_PORT}${path}"
  fi
}

curl_websocket() {
  local path="$1"

  if [[ "${HTTPS_ENABLED}" == "true" ]]; then
    curl -kfsS \
      --resolve "${WS_DOMAIN}:${HTTPS_PORT}:127.0.0.1" \
      --max-time "${DEPLOYMENT_HEALTH_TIMEOUT_SECONDS}" \
      "https://${WS_DOMAIN}:${HTTPS_PORT}${path}"
  else
    curl -fsS \
      -H "Host: ${WS_DOMAIN}" \
      --max-time "${DEPLOYMENT_HEALTH_TIMEOUT_SECONDS}" \
      "http://127.0.0.1:${HTTP_PORT}${path}"
  fi
}

curl_graphql() {
  local query="$1"

  if [[ "${HTTPS_ENABLED}" == "true" ]]; then
    curl -kfsS \
      --resolve "${ADMIN_DOMAIN}:${HTTPS_PORT}:127.0.0.1" \
      --max-time "${DEPLOYMENT_HEALTH_TIMEOUT_SECONDS}" \
      --get \
      --data-urlencode "query=${query}" \
      "https://${ADMIN_DOMAIN}:${HTTPS_PORT}/graphql"
  else
    curl -fsS \
      -H "Host: ${ADMIN_DOMAIN}" \
      --max-time "${DEPLOYMENT_HEALTH_TIMEOUT_SECONDS}" \
      --get \
      --data-urlencode "query=${query}" \
      "http://127.0.0.1:${HTTP_PORT}/graphql"
  fi
}

run_basic_health_check() {
  local failures=0
  local frontend_status=""
  local graphql_response=""

  echo "Running basic deployment health check..."

  frontend_status="$(curl_frontend "/" -o /dev/null -w "%{http_code}" || true)"
  if [[ "${frontend_status}" =~ ^2[0-9][0-9]$ ]]; then
    echo "[health] pass frontend / HTTP ${frontend_status}"
  else
    echo "[health] fail frontend / HTTP ${frontend_status:-request_failed}"
    failures=$((failures + 1))
  fi

  frontend_status="$(curl_frontend "/api/health" -o /dev/null -w "%{http_code}" || true)"
  if [[ "${frontend_status}" == "200" ]]; then
    echo "[health] pass frontend /api/health HTTP 200"
  else
    echo "[health] fail frontend /api/health HTTP ${frontend_status:-request_failed}"
    failures=$((failures + 1))
  fi

  if curl_websocket "/health" >/dev/null; then
    echo "[health] pass websocket /health"
  else
    echo "[health] fail websocket /health"
    failures=$((failures + 1))
  fi

  graphql_response="$(curl_graphql "{slugMappingTable{slug type id}}" || true)"
  if [[ -n "${graphql_response}" && "${graphql_response}" != *'"errors"'* ]]; then
    echo "[health] pass WordPress GraphQL route mapping"
  else
    echo "[health] fail WordPress GraphQL route mapping"
    printf '%s\n' "${graphql_response}"
    failures=$((failures + 1))
  fi

  if (( failures > 0 )); then
    echo "Deployment health conclusion: unhealthy basic_failures=${failures}"
    return 1
  fi

  echo "Deployment health conclusion: healthy basic_checks=4"
}

run_detailed_health_check() {
  local http_status=""

  echo "Running detailed deployment health check..."

  http_status="$(
    curl_frontend "/api/fd-debug/system-health" \
      -H "x-fd-debug-token: ${FD_DEBUG_TOKEN}" \
      -o "${tmp_health}" \
      -w "%{http_code}" || true
  )"

  if [[ ! -s "${tmp_health}" ]]; then
    echo "[health] fail detailed system health request returned no body. HTTP ${http_status:-request_failed}"
    return 1
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "${tmp_health}" "${http_status}" <<'PY'
import json
import sys

path = sys.argv[1]
http_status = sys.argv[2]

with open(path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)

summary = payload.get("summary") or {}
status = summary.get("status", "unknown")
print(
    "Deployment health conclusion: "
    f"status={status} score={summary.get('score', '-')} "
    f"pass={summary.get('pass', 0)} warn={summary.get('warn', 0)} fail={summary.get('fail', 0)} "
    f"total={summary.get('total', 0)} http={http_status}"
)

checks = payload.get("checks") or []
for check in checks:
    if check.get("status") == "pass":
        continue
    label = check.get("label") or check.get("id")
    message = check.get("message") or ""
    http = check.get("httpStatus")
    duration = check.get("durationMs")
    parts = [
        "[health]",
        str(check.get("status", "unknown")),
        str(check.get("group", "-")),
        str(label),
    ]
    if http is not None:
        parts.append(f"HTTP {http}")
    if duration is not None:
        parts.append(f"{duration}ms")
    if message:
        parts.append(str(message))
    print(" ".join(parts))

sys.exit(1 if status == "unhealthy" else 0)
PY
    return $?
  fi

  cat "${tmp_health}"
  if [[ "${http_status}" =~ ^2[0-9][0-9]$ ]]; then
    return 0
  fi
  return 1
}

if [[ "${FD_DEBUG_CONSOLE_ENABLED:-false}" == "true" && -n "${FD_DEBUG_TOKEN:-}" ]]; then
  run_detailed_health_check
else
  echo "Detailed health check skipped. Enable FD_DEBUG_CONSOLE_ENABLED=true and FD_DEBUG_TOKEN for full route/module conclusions."
  run_basic_health_check
fi
