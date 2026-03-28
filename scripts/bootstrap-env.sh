#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
EXAMPLE_FILE="${ROOT_DIR}/.env.example"

if [[ -f "${ENV_FILE}" ]]; then
  echo ".env already exists: ${ENV_FILE}"
  exit 0
fi

cp "${EXAMPLE_FILE}" "${ENV_FILE}"

generate_secret() {
  openssl rand -hex 32
}

replace_value() {
  local key="$1"
  local value="$2"
  perl -0pi -e "s/^${key}=.*$/${key}=${value}/m" "${ENV_FILE}"
}

replace_value "MYSQL_PASSWORD" "$(generate_secret)"
replace_value "MYSQL_ROOT_PASSWORD" "$(generate_secret)"
replace_value "JWT_SECRET" "$(generate_secret)"
replace_value "PUSH_SECRET" "$(generate_secret)"
replace_value "REVALIDATE_SECRET" "$(generate_secret)"

echo "Generated ${ENV_FILE}"
echo "Edit the domain and image settings before deployment."
