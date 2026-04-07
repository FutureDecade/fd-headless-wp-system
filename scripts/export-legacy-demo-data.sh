#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEGACY_WORDPRESS_SSH_HOST="${LEGACY_WORDPRESS_SSH_HOST:-82.157.22.93}"
LEGACY_WORDPRESS_REMOTE_DIR="${LEGACY_WORDPRESS_REMOTE_DIR:-/opt/wordpress}"
REMOTE_EXPORT_SCRIPT="${ROOT_DIR}/scripts/export-legacy-demo-data.remote.php"
OUTPUT_FILE="${OUTPUT_FILE:-${ROOT_DIR}/demo-data/legacy-site-demo-content.v1.json}"

if [[ ! -f "${REMOTE_EXPORT_SCRIPT}" ]]; then
  echo "Missing remote export script: ${REMOTE_EXPORT_SCRIPT}" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"

cat "${REMOTE_EXPORT_SCRIPT}" \
  | ssh "${LEGACY_WORDPRESS_SSH_HOST}" "cd '${LEGACY_WORDPRESS_REMOTE_DIR}' && docker compose exec -T wordpress php" \
  > "${OUTPUT_FILE}"

if command -v jq >/dev/null 2>&1; then
  jq '{manifest: .manifest, counts: .counts}' "${OUTPUT_FILE}"
elif command -v python3 >/dev/null 2>&1; then
  python3 - "${OUTPUT_FILE}" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    payload = json.load(handle)

print(json.dumps({
    'manifest': payload.get('manifest', {}),
    'counts': payload.get('counts', {}),
}, ensure_ascii=False, indent=2))
PY
fi

echo "Wrote demo data to ${OUTPUT_FILE}"
