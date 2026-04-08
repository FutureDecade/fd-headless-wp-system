#!/bin/bash
set -euo pipefail

REPO_DIR="/Users/admin/Projects/FutureDecade/fd-headless-wp-system"

echo "----------------------------------------"
echo "Sync fd-headless-wp-system"
echo "----------------------------------------"
echo

if [ ! -d "${REPO_DIR}/.git" ]; then
  echo "Repository not found:"
  echo "${REPO_DIR}"
  echo
  read -r -p "Press Enter to close..."
  exit 1
fi

cd "${REPO_DIR}"

echo "Repository:"
echo "${REPO_DIR}"
echo

echo "Fetching origin/main..."
git fetch origin main

echo
echo "Pulling latest changes..."
git pull --ff-only origin main

echo
echo "Current commit:"
git log -1 --oneline

echo
echo "Working tree status:"
git status --short

echo
echo "Sync completed."
echo
read -r -p "Press Enter to close..."
