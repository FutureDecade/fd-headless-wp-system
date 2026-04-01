#!/usr/bin/env bash

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
  local key=""
  local value=""

  if ! command -v jq >/dev/null 2>&1; then
    echo "缺少 jq，无法解析 FD Stack bootstrap 响应。"
    return 1
  fi

  export FD_STACK_BOOTSTRAP_JSON="${bootstrap_json}"

  install_path="$(printf '%s' "${bootstrap_json}" | jq -r '.bootstrap.installPath // empty')"
  repo_url="$(printf '%s' "${bootstrap_json}" | jq -r '.bootstrap.repository.url // empty')"
  repo_branch="$(printf '%s' "${bootstrap_json}" | jq -r '.bootstrap.repository.branch // empty')"

  if [[ -n "${install_path}" && -z "${INSTALL_DIR:-}" ]]; then
    export INSTALL_DIR="${install_path}"
  fi

  if [[ -n "${repo_url}" && -z "${REPO_URL:-}" ]]; then
    export REPO_URL="${repo_url}"
  fi

  if [[ -n "${repo_branch}" && -z "${REPO_BRANCH:-}" ]]; then
    export REPO_BRANCH="${repo_branch}"
  fi

  while IFS=$'\t' read -r key value; do
    if [[ -z "${key}" ]]; then
      continue
    fi

    if [[ -z "${!key:-}" ]]; then
      export "${key}=${value}"
    fi
  done < <(printf '%s' "${bootstrap_json}" | jq -r '.bootstrap.envDefaults // {} | to_entries[] | [.key, (.value | tostring)] | @tsv')
}

exchange_stack_bootstrap() {
  local exchange_url=""
  local response=""

  if [[ -z "${FD_STACK_DEPLOY_TOKEN:-}" ]]; then
    return 1
  fi

  if ! exchange_url="$(resolve_stack_exchange_url)"; then
    echo "检测到 FD_STACK_DEPLOY_TOKEN，但没有提供 FD_STACK_EXCHANGE_URL 或 FD_STACK_PUBLIC_BASE_URL。"
    return 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "缺少 curl，无法请求 FD Stack bootstrap 接口。"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "缺少 jq，无法解析 FD Stack bootstrap 响应。"
    return 1
  fi

  response="$(
    curl -fsSL -X POST "${exchange_url}" \
      -H 'content-type: application/json' \
      -d "{\"token\":\"${FD_STACK_DEPLOY_TOKEN}\"}"
  )"

  apply_stack_bootstrap_defaults "${response}"
}

load_stack_bootstrap() {
  if [[ -n "${FD_STACK_BOOTSTRAP_JSON:-}" ]]; then
    apply_stack_bootstrap_defaults "${FD_STACK_BOOTSTRAP_JSON}"
    return 0
  fi

  if [[ -n "${FD_STACK_DEPLOY_TOKEN:-}" ]]; then
    exchange_stack_bootstrap
    return 0
  fi

  return 1
}
