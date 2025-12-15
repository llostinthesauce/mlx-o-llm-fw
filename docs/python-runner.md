# Python Runner Setup (mlx-lm)

Use this when you want the bridge runner that shells out to `mlx_lm` without touching system Python.

## 1) Create a repo-local virtualenv
```bash
./scripts/bootstrap_python_venv.sh
```
This installs `upstream/mlx-lm` in editable mode into `.venv/` at the repo root.

## 2) Point the runner at that Python
- The CLI auto-detects `.venv/bin/python3`, or you can be explicit:
```bash
swift run mlxctl run \
  --runner python \
  --python-path .venv/bin/python3 \
  --model "Llama-3.2-3B-Instruct-mlx-4Bit" \
  --model-paths-json config/model-paths.local.json \
  --prompt "Hello"
```
You can also export `MLX_PYTHON=.venv/bin/python3`.

## 3) Cache flags for SwiftPM (if you see sandbox cache errors)
Run with repo-local caches:
```bash
env MODULE_CACHE_DIR=$(pwd)/.build/module-cache \
    CLANG_MODULE_CACHE_PATH=$(pwd)/.build/clang-cache \
    swift run --cache-path .build/swiftpm-cache mlxctl --help
```
Or use the helper for tests: `./scripts/swift-test-local.sh`.
