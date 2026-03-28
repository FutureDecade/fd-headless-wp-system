#!/usr/bin/env bash
set -euo pipefail

INSTALL_BASE_PACKAGES="${INSTALL_BASE_PACKAGES:-true}"
INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
INSTALL_GH_CLI="${INSTALL_GH_CLI:-true}"
DOCKER_CHANNEL="${DOCKER_CHANNEL:-stable}"
DRY_RUN="${DRY_RUN:-false}"

print_step() {
  echo
  echo "==> $1"
}

run_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '+'
    for arg in "$@"; do
      printf ' %q' "${arg}"
    done
    printf '\n'
    return 0
  fi

  "$@"
}

run_root_cmd() {
  if [[ "${EUID}" -eq 0 ]]; then
    run_cmd "$@"
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "This script needs root privileges. Re-run as root or install sudo."
    exit 1
  fi

  run_cmd sudo "$@"
}

write_root_file() {
  local path="$1"
  local content="$2"

  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '+ write %q\n' "${path}"
    printf '%s\n' "${content}"
    return 0
  fi

  if [[ "${EUID}" -eq 0 ]]; then
    printf '%s\n' "${content}" > "${path}"
    return 0
  fi

  printf '%s\n' "${content}" | sudo tee "${path}" >/dev/null
}

download_to_root_file() {
  local url="$1"
  local path="$2"

  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '+ curl -fsSL %q > %q\n' "${url}" "${path}"
    return 0
  fi

  if [[ "${EUID}" -eq 0 ]]; then
    curl -fsSL "${url}" -o "${path}"
    return 0
  fi

  curl -fsSL "${url}" | sudo tee "${path}" >/dev/null
}

check_boolean_value() {
  local key="$1"
  local value="$2"

  case "${value}" in
    true|false)
      ;;
    *)
      echo "${key} must be true or false. Current value: ${value}"
      exit 1
      ;;
  esac
}

require_command() {
  local cmd="$1"

  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}"
    exit 1
  fi
}

check_boolean_value "INSTALL_BASE_PACKAGES" "${INSTALL_BASE_PACKAGES}"
check_boolean_value "INSTALL_DOCKER" "${INSTALL_DOCKER}"
check_boolean_value "INSTALL_GH_CLI" "${INSTALL_GH_CLI}"
check_boolean_value "DRY_RUN" "${DRY_RUN}"

if [[ ! -f /etc/os-release ]]; then
  echo "Unsupported system: missing /etc/os-release"
  exit 1
fi

# shellcheck source=/dev/null
source /etc/os-release

DISTRO_ID="${ID:-}"
DISTRO_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
DISTRO_NAME="${PRETTY_NAME:-${DISTRO_ID}}"

if [[ "${DISTRO_ID}" != "debian" && "${DISTRO_ID}" != "ubuntu" ]]; then
  echo "This script currently supports Debian or Ubuntu. Current system: ${DISTRO_NAME}"
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script requires apt-get."
  exit 1
fi

if [[ -z "${DISTRO_CODENAME}" ]]; then
  echo "Unable to detect distro codename from /etc/os-release"
  exit 1
fi

if [[ "${DOCKER_CHANNEL}" != "stable" && "${DOCKER_CHANNEL}" != "test" && "${DOCKER_CHANNEL}" != "nightly" ]]; then
  echo "DOCKER_CHANNEL must be stable, test, or nightly. Current value: ${DOCKER_CHANNEL}"
  exit 1
fi

check_conflicting_docker_packages() {
  local conflicts=(
    docker.io
    docker-doc
    docker-compose
    podman-docker
    containerd
    runc
  )
  local installed=()
  local pkg=""

  for pkg in "${conflicts[@]}"; do
    if dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "install ok installed"; then
      installed+=("${pkg}")
    fi
  done

  if (( ${#installed[@]} > 0 )); then
    echo "Found existing Docker-related packages: ${installed[*]}"
    echo "为了稳妥，这个脚本不会自动删除旧包。"
    echo "请先手工确认并处理这些包，再重新运行。"
    exit 1
  fi
}

install_base_packages() {
  print_step "Installing base packages"
  run_root_cmd apt-get update
  run_root_cmd apt-get install -y \
    ca-certificates \
    curl \
    git \
    gnupg \
    lsb-release \
    openssl \
    perl \
    unzip
}

install_docker() {
  print_step "Installing Docker Engine and Docker Compose"
  require_command curl
  check_conflicting_docker_packages

  run_root_cmd install -m 0755 -d /etc/apt/keyrings
  download_to_root_file "https://download.docker.com/linux/${DISTRO_ID}/gpg" "/etc/apt/keyrings/docker.asc"
  run_root_cmd chmod a+r /etc/apt/keyrings/docker.asc

  write_root_file \
    "/etc/apt/sources.list.d/docker.list" \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DISTRO_ID} ${DISTRO_CODENAME} ${DOCKER_CHANNEL}"

  run_root_cmd apt-get update
  run_root_cmd apt-get install -y \
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin

  if command -v systemctl >/dev/null 2>&1; then
    run_root_cmd systemctl enable --now docker
  else
    echo "systemctl not found. Please start Docker service manually."
  fi
}

install_github_cli() {
  print_step "Installing GitHub CLI"
  require_command curl

  run_root_cmd install -m 0755 -d /usr/share/keyrings
  download_to_root_file \
    "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
    "/usr/share/keyrings/githubcli-archive-keyring.gpg"
  run_root_cmd chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

  write_root_file \
    "/etc/apt/sources.list.d/github-cli.list" \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"

  run_root_cmd apt-get update
  run_root_cmd apt-get install -y gh
}

print_step "Server bootstrap target"
echo "System: ${DISTRO_NAME}"
echo "INSTALL_BASE_PACKAGES=${INSTALL_BASE_PACKAGES}"
echo "INSTALL_DOCKER=${INSTALL_DOCKER}"
echo "INSTALL_GH_CLI=${INSTALL_GH_CLI}"
echo "DRY_RUN=${DRY_RUN}"

if [[ "${INSTALL_BASE_PACKAGES}" == "true" ]]; then
  install_base_packages
fi

if [[ "${INSTALL_DOCKER}" == "true" ]]; then
  install_docker
fi

if [[ "${INSTALL_GH_CLI}" == "true" ]]; then
  install_github_cli
fi

print_step "Installed versions"

if command -v git >/dev/null 2>&1; then
  git --version
fi

if command -v docker >/dev/null 2>&1; then
  docker --version
  docker compose version
fi

if command -v gh >/dev/null 2>&1; then
  gh --version
fi

print_step "Next"
echo "1. Clone the delivery repo if you have not done it yet."
echo "2. Enter the repo directory."
echo "3. Run: bash scripts/configure-env.sh"
echo "4. Then run: bash scripts/install.sh"
