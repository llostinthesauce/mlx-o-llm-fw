#!/usr/bin/env bash
set -euo pipefail

# Create a repo-local virtualenv and install mlx-lm in editable mode so the Python runner
# can execute without depending on system-wide packages.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${ROOT}/.venv"

python3 -m venv "${VENV}"
source "${VENV}/bin/activate"

pip install --upgrade pip
pip install -e "${ROOT}/upstream/mlx-lm"

echo
echo "Virtualenv ready at ${VENV}"
echo "Use ${VENV}/bin/python3 or set MLX_PYTHON=${VENV}/bin/python3 when running:"
echo "  swift run mlxctl run --runner python --python-path ${VENV}/bin/python3 --model <name> --prompt \"Hi\""
