# Upstream Reference Map

Current clones under `./upstream/` and how to use them as references (read-only unless explicitly forked).

- `upstream/ollama`: Behavioral spec for CLI/API, Modelfile-like recipes, model lifecycle, diff pulls, store layout. Useful for matching UX and external contracts; avoid pulling runtime internals directly.
- `upstream/mlx-swift`: Ground-truth Swift APIs/patterns for MLX on Apple silicon. Use for implementing `MLXInferenceKit` and for understanding array/kernel behavior.
- `upstream/mlx-swift-examples`: Practical MLX Swift samples, including CLI patterns and download flows; good for scaffolding inference demos and tests.
- `upstream/mlx-lm`: Reference for MLX model conversion/quantization and HF integration. Keep as a workflow guide for ModelSpec/build tooling.
- `upstream/fastmlx`: OpenAI-compatible API semantics and streaming behavior in an MLX context; use as a semantic contract while keeping daemon Swift-native.
- `upstream/swift-argument-parser`: Best-practice Swift CLI scaffolding; source patterns for `mlxctl`.
- `upstream/oci-distribution-spec` & `upstream/oci-image-spec`: Distribution/image specs for blob/manifest formats; align ModelStoreKit and registry flows to these shapes.
- `upstream/oras-go` & `upstream/oras-cli`: Reference implementations of OCI artifact pull/push and progress reporting; good guides for diff-pull/publish behavior.
