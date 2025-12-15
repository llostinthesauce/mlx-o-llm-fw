#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-submodule}"   # submodule | clone
UPSTREAM_DIR="${2:-upstream}"

REPOS=(
  "https://github.com/ollama/ollama.git|ollama"
  "https://github.com/ml-explore/mlx-swift.git|mlx-swift"
  "https://github.com/ml-explore/mlx-swift-examples.git|mlx-swift-examples"
  "https://github.com/ml-explore/mlx-lm.git|mlx-lm"
  "https://github.com/arcee-ai/fastmlx.git|fastmlx"
  "https://github.com/apple/swift-argument-parser.git|swift-argument-parser"

  # OCI / registry refs (enabled)
  "https://github.com/opencontainers/distribution-spec.git|oci-distribution-spec"
  "https://github.com/opencontainers/image-spec.git|oci-image-spec"
  "https://github.com/oras-project/oras-go.git|oras-go"
  "https://github.com/oras-project/oras.git|oras-cli"
)

if [[ ! -d ".git" ]]; then
  echo "ERROR: Run this from the root of a git repository (missing .git/)."
  exit 1
fi

mkdir -p "${UPSTREAM_DIR}"

add_submodule () {
  local url="$1"
  local name="$2"
  local dest="${UPSTREAM_DIR}/${name}"

  if [[ -d "${dest}" ]]; then
    echo "SKIP (exists): ${dest}"
    return 0
  fi

  echo "ADD SUBMODULE: ${name}"
  git submodule add "${url}" "${dest}"
}

clone_repo () {
  local url="$1"
  local name="$2"
  local dest="${UPSTREAM_DIR}/${name}"

  if [[ -d "${dest}" ]]; then
    echo "SKIP (exists): ${dest}"
    return 0
  fi

  echo "CLONE: ${name}"
  git clone --depth 1 "${url}" "${dest}"
}

case "${MODE}" in
  submodule)
    echo "Mode: submodule"
    for entry in "${REPOS[@]}"; do
      url="${entry%%|*}"
      name="${entry##*|}"
      add_submodule "${url}" "${name}"
    done
    echo "Initializing/updating submodules..."
    git submodule update --init --recursive
    ;;
  clone)
    echo "Mode: clone"
    for entry in "${REPOS[@]}"; do
      url="${entry%%|*}"
      name="${entry##*|}"
      clone_repo "${url}" "${name}"
    done
    ;;
  *)
    echo "Usage: $0 [submodule|clone] [upstream_dir]"
    exit 1
    ;;
esac

echo "Done. Contents:"
ls -la "${UPSTREAM_DIR}"
