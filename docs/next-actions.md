# Near-Term Implementation Plan

Actionable tasks to get from current repo state to a usable MVP skeleton. Focus is Milestones 0–3 from the scope doc.

## Prep
- [ ] Confirm Swift toolchain + MLX Swift build on local machine (run `swift test` in `upstream/mlx-swift` as a sanity check).
- [x] Decide package layout for `MLXInferenceKit` and `ModelStoreKit` (Swift Packages at repo root vs `Sources/` tree).
- [ ] Choose minimal demo model for smoke tests (e.g., a small Llama/Gemma variant) and cache its HF revision/tag.
- [ ] Run `scripts/swift-test-local.sh` locally (uses repo-local caches to avoid sandbox permission issues).
- [ ] Fill `config/model-paths.example.json` with your real local model paths (copy to a local file) for the `mlx-demo --runner local` smoke.
- [ ] Add real HF tokenizer loader (replace placeholder HFTokenizerLoader returning WhitespaceTokenizer).

## Milestone 0 — Extraction Spike
- [x] Define `ModelRunner` protocol (load, unload, generate(stream), optional embeddings later); include basic configuration struct for defaults.
- [ ] Implement `MLXModelAdapter` backed by MLX Swift (bridge from GUI inference code) and plug into `MLXRunner` (skeleton adapter added as placeholder).
- [ ] Port existing GUI inference loop into `MLXRunner` (implements `ModelRunner`) with streaming via `AsyncSequence`.
- [x] Add tokenization + chat templating helpers (start with one template: Llama). Provide a simple `PromptBuilder`.
- [x] Write a tiny CLI sample (temporary) to load the demo model and stream tokens to stdout.
- [x] Add a smoke test that runs a short generation against a stub/mock runner.
- [ ] Replace temporary `LocalMLXRunner` placeholder with real MLX-backed loading of the known-good model format.
- [ ] Wire `MLXSwiftAdapter` to real MLX Swift load/generate; point to one known-good model path and validate via `mlx-demo --runner local`.
- [x] Add tokenizer wiring (HF assets) for the first supported model; integrate PromptBuilder output with tokenizer (using swift-transformers AutoTokenizer).
- [ ] Run `mlxctl run --runner local` against a real model to validate streaming.
- [x] Replace placeholder vocab tokenizer with real HF tokenizer.
- [ ] (Interim) Validate `mlxctl run --runner python` using `python -m mlx_lm.generate` bridge for a known model path.

## Milestone 1 — Daemon + CLI Skeleton
- [x] Scaffold `mlxserve` with `/api/health`, `/api/generate` (basic HTTP over Network framework; NDJSON streaming placeholder).
- [ ] Implement request normalization → template → tokenizer → `ModelRunner.generate` (real MLX adapter pending).
- [ ] Add cancellation handling (client disconnect aborts generation).
- [x] Scaffold `mlxctl serve` that calls the daemon; include local config for host/port.
- [ ] Add structured logging (JSONL) with request ids and timing.
- [ ] Add `/api/version`, `/api/chat`, `/v1/chat/completions` streaming parity.

## Milestone 2 — Store Primitives
- [x] Create `ModelStoreKit` layout: `blobs/sha256/<digest>`, `manifests/<tag>.json`, indexes. (FileModelStore skeleton)
- [x] Implement tag CRUD (`list/show/rm`) and digest verification (blob import + verify).
- [x] Wire `mlxctl list/show/rm/import/verify` to the store; keep offline (no daemon) path.
- [ ] Add integrity checks in the daemon on load (manifest exists, blobs match digest).

## Milestone 3 — Pull + Progress
- [ ] Implement pull from HTTP/local packages with progress streaming; store blobs/manifests in `ModelStoreKit`.
- [ ] Perform digest-based delta pulls (skip existing blobs).
- [ ] Align manifest format to OCI/ORAS shapes (descriptor media types, sizes, digests) even before push exists.
- [ ] Expose `mlxctl pull` and `/api/pull` with progress events.

## Cross-Cutting
- [ ] Pick streaming format for daemon (SSE vs NDJSON) and keep consistent across native + OpenAI endpoints.
- [ ] Document ModelSpec draft schema and default templates/params; keep in repo for early feedback.
- [x] Add ModelSpec draft schema and CLI validate/pack support.
- [ ] Establish concurrency/residency defaults (keep-alive, max loaded models, queue cap) and configure via `config.json`.
- [ ] Add basic metrics hooks (tokens/sec, queue depth) and a minimal `/api/ps` shape for later.

## Open Questions to Resolve Early
- Which tokenizer strategy: HF assets directly vs. a Swift tokenizer lib cached locally?
- Where to store ModelSpec/build outputs in the repo (e.g., `models/` vs. user home cache)?
- Minimum macOS version and Swift toolchain target (affects Vapor/SwiftNIO versions).
