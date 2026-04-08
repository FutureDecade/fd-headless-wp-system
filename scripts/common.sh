#!/usr/bin/env bash

load_env_file() {
  local env_file="$1"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"

    if [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    if [[ "${line}" != *=* ]]; then
      continue
    fi

    local key="${line%%=*}"
    local value="${line#*=}"

    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"

    if [[ "${value}" =~ ^\".*\"$ || "${value}" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi

    export "${key}=${value}"
  done < "${env_file}"
}

set_env_value() {
  local env_file="$1"
  local key="$2"
  local value="$3"
  local tmp_file=""

  tmp_file="$(mktemp "${env_file}.XXXXXX")"

  awk -v key="${key}" -v value="${value}" '
    BEGIN {
      updated = 0
    }
    $0 ~ ("^" key "=") {
      if (!updated) {
        print key "=" value
        updated = 1
      }
      next
    }
    {
      print
    }
    END {
      if (!updated) {
        print key "=" value
      }
    }
  ' "${env_file}" > "${tmp_file}"

  mv "${tmp_file}" "${env_file}"
}

unset_env_value() {
  local env_file="$1"
  local key="$2"
  local tmp_file=""

  if [[ ! -f "${env_file}" ]]; then
    return 0
  fi

  tmp_file="$(mktemp "${env_file}.XXXXXX")"

  awk -v key="${key}" '
    $0 ~ ("^" key "=") {
      next
    }
    {
      print
    }
  ' "${env_file}" > "${tmp_file}"

  mv "${tmp_file}" "${env_file}"
}

unset_env_keys() {
  local env_file="$1"
  shift
  local key=""

  for key in "$@"; do
    unset_env_value "${env_file}" "${key}"
  done
}
