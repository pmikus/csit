#!/bin/bash

# Copyright (c) 2025 Cisco and/or its affiliates.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Strict mode
set -euo pipefail
IFS=$' \t\n'

trap 'ec=$?; echo "[ERROR] setup_executor_env.sh failed at line $LINENO with exit code $ec" >&2' ERR

# Load OS metadata
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_VERSION_ID="${VERSION_ID:-unknown}"
else
  OS_ID="unknown"
  OS_VERSION_ID="unknown"
fi
OS_ARCH=$(uname -m)

file_delimiter="----- %< -----"
long_line="************************************************************************"
# Original downloads cache (may be ephemeral inside container)
downloads_cache="/root/Downloads"

GITHUB_RUNNER="${RUNNER_NAME:-Unknown}"
GITHUB_WORKFLOW="${GITHUB_WORKFLOW:-Unknown}"
GITHUB_RUN_ID="${GITHUB_RUN_ID:-Unknown}"

# Toggle envs (can be overridden from workflow)
: "${VERBOSE_PACKAGES:=1}"      # 1 to list installed OS packages
: "${VERBOSE_PY:=1}"            # 1 to list python packages
: "${CCACHE_MAXSIZE:=20G}"      # Max ccache size
: "${CCACHE_COMPILERCHECK:=content}" # Safer compiler change detection

log_line() { echo "$long_line"; }

setup_ccache() {
  log_line
  if command -v ccache >/dev/null 2>&1; then
    # Ensure CCACHE_DIR is set and exists
    if [ -z "${CCACHE_DIR:-}" ]; then
      # Derive a default if not provided (caller may pass one via env)
      CCACHE_DIR="/scratch/ccache/${OS_ID}-${OS_VERSION_ID}-${OS_ARCH}"
      export CCACHE_DIR
    fi
    if [ ! -d "${CCACHE_DIR}" ]; then
      echo "Creating CCACHE_DIR='${CCACHE_DIR}'"
      if ! mkdir -p "${CCACHE_DIR}" 2>/dev/null; then
        echo "Failed to create CCACHE_DIR; disabling ccache"
        export CCACHE_DISABLE=1
      fi
    fi
    if [ -z "${CCACHE_DISABLE:-}" ]; then
      export CCACHE_MAXSIZE CCACHE_COMPILERCHECK
      echo "ccache enabled: dir='${CCACHE_DIR}' max='${CCACHE_MAXSIZE}' compilercheck='${CCACHE_COMPILERCHECK}'"
      echo "Initial ccache stats:"; ccache -s || true
    else
      echo "ccache explicitly disabled (CCACHE_DISABLE='${CCACHE_DISABLE}')"
    fi
  else
    echo "WARNING: ccache is not installed (will proceed without caching)"
    export CCACHE_DISABLE=1
  fi
}

prepare_workspace_cache() {
  # Update cache directory for GitHub Actions (for other tooling reuse)
  downloads_cache="${GITHUB_WORKSPACE:-/github/workspace}/.cache"
  mkdir -p "${downloads_cache}" 2>/dev/null || true
  log_line
}

# Execution sequence
setup_ccache
prepare_workspace_cache

# Success footer
echo "Executor environment setup complete."
