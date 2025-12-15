#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
RUNTIME_MLX="$BUILD_DIR/mlx-runtime/mlx/lib"
export SWIFT_MODULE_CACHE_PATH="${SWIFT_MODULE_CACHE_PATH:-$BUILD_DIR/swift-module-cache}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$BUILD_DIR/clang-module-cache}"

# Default metallib location (from pip-installed mlx). Override with MLX_METAL_PATH if desired.
if [[ -d "$RUNTIME_MLX" && -f "$RUNTIME_MLX/mlx.metallib" ]]; then
  export MLX_METAL_PATH="${MLX_METAL_PATH:-$RUNTIME_MLX}"
fi

exe="$BUILD_DIR/arm64-apple-macosx/debug/mlxctl"
if [[ ! -x "$exe" ]]; then
  echo "Building mlxctl..."
  swift build --cache-path "$BUILD_DIR/swiftpm-cache"
fi

echo "Using MLX_METAL_PATH=${MLX_METAL_PATH:-'(not set)'}"
echo "Running: mlxctl $*"
exec "$exe" "$@"
