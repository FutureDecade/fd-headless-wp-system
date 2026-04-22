#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMER_NAME="${TIMER_NAME:-fd-deployment-action-runner}"
SERVICE_FILE="/etc/systemd/system/${TIMER_NAME}.service"
TIMER_FILE="/etc/systemd/system/${TIMER_NAME}.timer"
POLL_INTERVAL="${POLL_INTERVAL:-1min}"

run_root_cmd() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "This script needs root privileges. Re-run as root or install sudo."
    exit 1
  fi

  sudo "$@"
}

write_root_file() {
  local path="$1"
  local content="$2"

  if [[ "${EUID}" -eq 0 ]]; then
    printf '%s\n' "${content}" > "${path}"
    return 0
  fi

  printf '%s\n' "${content}" | sudo tee "${path}" >/dev/null
}

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemctl is not available. This helper currently supports systemd only."
  exit 1
fi

write_root_file "${SERVICE_FILE}" "[Unit]
Description=FD deployment action runner
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=${ROOT_DIR}
ExecStart=${ROOT_DIR}/scripts/run-pending-deployment-action.sh
"

write_root_file "${TIMER_FILE}" "[Unit]
Description=Run FD deployment action runner periodically

[Timer]
OnBootSec=2min
OnUnitActiveSec=${POLL_INTERVAL}
Unit=${TIMER_NAME}.service
Persistent=true

[Install]
WantedBy=timers.target
"

run_root_cmd systemctl daemon-reload
run_root_cmd systemctl enable --now "${TIMER_NAME}.timer"

echo "Installed ${TIMER_NAME}.service and ${TIMER_NAME}.timer"
echo "Poll interval: ${POLL_INTERVAL}"
echo "Check status with: systemctl status ${TIMER_NAME}.timer"
