#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/common.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env file. Skip frontend warmup."
  exit 0
fi

load_env_file "${ENV_FILE}"

FRONTEND_WARMUP_ENABLED="${FRONTEND_WARMUP_ENABLED:-true}"
FRONTEND_WARMUP_MAX_POSTS="${FRONTEND_WARMUP_MAX_POSTS:-8}"
FRONTEND_WARMUP_MAX_PAGES="${FRONTEND_WARMUP_MAX_PAGES:-8}"
FRONTEND_WARMUP_MAX_TERMS="${FRONTEND_WARMUP_MAX_TERMS:-8}"
FRONTEND_WARMUP_TIMEOUT_SECONDS="${FRONTEND_WARMUP_TIMEOUT_SECONDS:-10}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_ENABLED="${HTTPS_ENABLED:-false}"
HTTPS_PORT="${HTTPS_PORT:-443}"

if [[ "${FRONTEND_WARMUP_ENABLED}" != "true" ]]; then
  echo "FRONTEND_WARMUP_ENABLED=false, skipping frontend warmup."
  exit 0
fi

if [[ -z "${FRONTEND_DOMAIN:-}" || -z "${ADMIN_DOMAIN:-}" ]]; then
  echo "FRONTEND_DOMAIN or ADMIN_DOMAIN is missing. Skip frontend warmup."
  exit 0
fi

request_frontend_path() {
  local path="$1"

  if [[ "${HTTPS_ENABLED}" == "true" ]]; then
    curl -kfsS \
      --resolve "${FRONTEND_DOMAIN}:${HTTPS_PORT}:127.0.0.1" \
      --max-time "${FRONTEND_WARMUP_TIMEOUT_SECONDS}" \
      -o /dev/null \
      "https://${FRONTEND_DOMAIN}:${HTTPS_PORT}${path}"
  else
    curl -fsS \
      -H "Host: ${FRONTEND_DOMAIN}" \
      --max-time "${FRONTEND_WARMUP_TIMEOUT_SECONDS}" \
      -o /dev/null \
      "http://127.0.0.1:${HTTP_PORT}${path}"
  fi
}

query_admin_graphql() {
  local payload="$1"

  if [[ "${HTTPS_ENABLED}" == "true" ]]; then
    curl -kfsS \
      --resolve "${ADMIN_DOMAIN}:${HTTPS_PORT}:127.0.0.1" \
      -H 'Content-Type: application/json' \
      --max-time "${FRONTEND_WARMUP_TIMEOUT_SECONDS}" \
      --data "${payload}" \
      "https://${ADMIN_DOMAIN}:${HTTPS_PORT}/graphql"
  else
    curl -fsS \
      -H "Host: ${ADMIN_DOMAIN}" \
      -H 'Content-Type: application/json' \
      --max-time "${FRONTEND_WARMUP_TIMEOUT_SECONDS}" \
      --data "${payload}" \
      "http://127.0.0.1:${HTTP_PORT}/graphql"
  fi
}

seed_query_payload="$(cat <<JSON
{"query":"query WarmupSeed(\$posts: Int!, \$pages: Int!, \$terms: Int!) { routePrefixes { postPrefix categoryPrefix tagPrefix categoryIndexRoute tagIndexRoute customTypePrefix } posts(first: \$posts, where: { orderby: { field: DATE, order: DESC } }) { nodes { shortUuid slug } } pages(first: \$pages) { nodes { slug } } categories(first: \$terms) { nodes { slug count } } tags(first: \$terms) { nodes { slug count } } getAllPublicCptSlugs { slug } }","variables":{"posts":${FRONTEND_WARMUP_MAX_POSTS},"pages":${FRONTEND_WARMUP_MAX_PAGES},"terms":${FRONTEND_WARMUP_MAX_TERMS}}}
JSON
)"

tmp_routes="$(mktemp)"
tmp_seed="$(mktemp)"

cleanup() {
  rm -f "${tmp_routes}" "${tmp_seed}"
}
trap cleanup EXIT

if command -v python3 >/dev/null 2>&1; then
  if query_admin_graphql "${seed_query_payload}" > "${tmp_seed}" 2>/dev/null; then
    python3 - "${tmp_seed}" > "${tmp_routes}" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)

data = payload.get("data") or {}
prefixes = {
    "postPrefix": "post",
    "categoryPrefix": None,
    "tagPrefix": None,
    "categoryIndexRoute": "category-index",
    "tagIndexRoute": "tag-index",
    "customTypePrefix": None,
}
prefixes.update(data.get("routePrefixes") or {})

paths = [
    "/",
    "/search",
    "/sitemap.xml",
    f"/{prefixes['categoryIndexRoute']}",
    f"/{prefixes['tagIndexRoute']}",
]

for node in (data.get("posts") or {}).get("nodes") or []:
    uuid = (node or {}).get("shortUuid")
    slug = (node or {}).get("slug")
    if uuid and slug:
        paths.append(f"/{prefixes['postPrefix']}/{uuid}/{slug}")

for node in (data.get("pages") or {}).get("nodes") or []:
    slug = (node or {}).get("slug")
    if slug:
        paths.append(f"/{slug}")

for node in (data.get("categories") or {}).get("nodes") or []:
    slug = (node or {}).get("slug")
    count = (node or {}).get("count")
    if not slug or count == 0:
        continue
    prefix = prefixes.get("categoryPrefix")
    paths.append(f"/{prefix}/{slug}" if prefix else f"/{slug}")

for node in (data.get("tags") or {}).get("nodes") or []:
    slug = (node or {}).get("slug")
    count = (node or {}).get("count")
    if not slug or count == 0:
        continue
    prefix = prefixes.get("tagPrefix")
    paths.append(f"/{prefix}/{slug}" if prefix else f"/{slug}")

for node in data.get("getAllPublicCptSlugs") or []:
    slug = (node or {}).get("slug")
    if slug:
        paths.append(f"/{slug}")

seen = set()
for value in paths:
    if not value or value in seen:
        continue
    seen.add(value)
    print(value)
PY
  fi
fi

if [[ ! -s "${tmp_routes}" ]]; then
  cat > "${tmp_routes}" <<'EOF'
/
/search
/category-index
/tag-index
/sitemap.xml
EOF
fi

echo "Warming frontend cache via ${FRONTEND_DOMAIN}..."

success_count=0
failure_count=0

while IFS= read -r path || [[ -n "${path}" ]]; do
  [[ -z "${path}" ]] && continue

  if request_frontend_path "${path}"; then
    printf '[warmup] ok   %s\n' "${path}"
    success_count=$((success_count + 1))
  else
    printf '[warmup] fail %s\n' "${path}"
    failure_count=$((failure_count + 1))
  fi
done < "${tmp_routes}"

printf 'Frontend warmup finished. success=%s failure=%s\n' "${success_count}" "${failure_count}"
