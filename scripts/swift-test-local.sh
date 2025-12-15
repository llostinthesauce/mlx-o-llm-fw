#!/usr/bin/env bash
set -euo pipefail

# Runs swift test with repo-local caches to avoid permission issues in sandboxed environments.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export SWIFTPM_CONFIGURATION_PATH="${ROOT}/.swiftpm/configuration"
export SWIFTPM_SECURITY_PATH="${ROOT}/.swiftpm/security"
export SWIFTPM_SHARED_CACHE_DISABLE=1
export SWIFT_BUILD_DIR="${ROOT}/.build-local"
export SWIFT_TEST_DIR="${ROOT}/.build-local"

mkdir -p "${SWIFTPM_CONFIGURATION_PATH}" "${SWIFTPM_SECURITY_PATH}" "${SWIFT_BUILD_DIR}"

exec swift test --package-path "${ROOT}" "$@"
