# MLX-Ollama Work Chunks

Working plan broken into buildable chunks so we can track progress across the SDK, daemon, CLI, and model store.

## Core Modules (targets)
- `MLXInferenceKit` (Swift Package): shared inference engine; tokenization, templating, streaming primitives, async generation and embeddings (later).
- `ModelStoreKit` (Swift Package): content-addressed blobs + manifests, tag resolution, provenance, GC, registry client abstraction.
- `mlxserve` (macOS daemon): HTTP server with native + OpenAI-compatible endpoints; scheduler for load/unload, keep-alive, queue/backpressure.
- `mlxctl` (CLI): wraps daemon lifecycle and store ops; provides `serve/pull/list/show/rm/run/chat/create/ps/stop/bench/pack/push`.
- ModelSpec/build pipeline: Modelfile-like recipes → manifest + blobs; verification tooling.

## Chunked Work (near-term)
- [ ] Extraction spike (Milestone 0): lift existing MLX Swift inference loop into `MLXInferenceKit` with a stable `ModelRunner` protocol and minimal tests; wire a throwaway CLI to stream tokens from one known-good model.
- [ ] Daemon + CLI skeleton (Milestone 1): `mlxserve` with `/api/health`, `/api/version`, `/api/generate` streaming; `mlxctl serve` + `mlxctl run` hitting the daemon.
- [ ] Store primitives (Milestone 2): local content-addressed layout (`blobs/`, `manifests/`, indexes) with tag CRUD; CLI `list/show/rm`; seed integrity checks.
- [ ] Pull/progress (Milestone 3): implement pull from HTTP/local packages; progress streaming; digest-based delta pulls; align to OCI/ORAS shapes early even if push waits.
- [ ] OpenAI compatibility (Milestone 4): `/v1/chat/completions` streaming + non-stream via Vapor/SwiftNIO; validate with OpenAI SDK pointing at localhost.
- [ ] ModelSpec/create (Milestone 5): `mlxctl create -f ModelSpec.yaml` producing manifest+blobs; `verify`; default templates/params; quantization flags passthrough.
- [ ] Embeddings + hardening (Milestone 6): `/api/embed`, `/v1/embeddings`; scheduler knobs (keep-alive, queue caps); cancellation; integration tests; perf baselines.
- [ ] Publishing (Milestone 7, optional): OCI/ORAS push/pack; registry auth/config; provenance recording.

## Cross-Cutting Threads
- Tokenization/templates: decide HF asset handling vs. Swift tokenizer library; ship a small template catalog (Llama, Qwen, Gemma, etc.).
- Residency & scheduling: keep-alive defaults, eviction policy, memory budgeting heuristics, cancellation on disconnect.
- Observability: JSONL logging + basic metrics; CLI/daemon verbose switches.
- Security: localhost bind by default; opt-in LAN; doc exposure risks.

## Immediate Focus (per scope doc)
- Define `ModelRunner` + streaming primitives in `MLXInferenceKit` and port one end-to-end generate path.
- Stand up `mlxserve` shell with `/v1/chat/completions` (streaming) using the shared runner.
- Lay the `ModelStoreKit` skeleton (digests, manifests, tag index) and wire `mlxctl pull/list/show/run` against it.
