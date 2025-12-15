# Next Steps and Ollama Gap Check

This file captures the immediate work plan and how it maps to missing Ollama-like features.

## Execution Plan (shortlist)
- **Native MLX runner**: Replace the python bridge with real MLXSwiftAdapter load/generate; wire HF tokenizer + prompt template; add a smoke test using `config/model-paths.local.json`.
- **Daemon parity**: Move `mlxserve` to Vapor/SwiftNIO; default to GPU runner with CPU fallback; implement `/api/health`, `/api/version`, `/api/generate`, `/api/chat`, `/v1/chat/completions` with SSE/NDJSON streaming, cancellation, and JSONL request logs.
- **Store integrity & pull**: Enforce manifest/blob verification on load; add `mlxctl pull` + `/api/pull` with progress and digest-based skips; align manifests to OCI descriptors.
- **ModelSpec/recipes**: Finalize ModelSpec schema and defaults; implement `mlxctl create/pack` to produce manifests/blobs; include a default Llama template.
- **Scheduler/residency**: Add keep-alive defaults, max loaded models, queue caps, and `/api/ps`; cancel on disconnect.
- **OpenAI compatibility**: Harden response shapes (usage, ids), support streaming/non-streaming, and add `/v1/embeddings` once runner supports it.
- **Observability**: Standardize SSE/NDJSON logging, basic metrics (tokens/sec, queue depth), and verbose flags in CLI/daemon.

## Gaps vs Ollama (what’s missing)
- **Runtime**: Native MLX Swift runner not yet shipped; python bridge is temporary.
- **Daemon**: Current HTTP server is minimal; needs production HTTP stack, scheduling, cancellation, and consistent streaming formats.
- **Store/Registry**: Local store exists; missing integrity enforcement on load and OCI-aligned pull/delta flows; no pull/push commands yet.
- **CLI surface**: Only `run/serve/store` basics; missing `pull`, `create`, `ps`, `stop`, `bench`, `chat` parity.
- **ModelSpec**: Draft only; needs schema, defaults, and `create/pack`.
- **OpenAI API**: Stubbed shapes/endpoints; needs full streaming/non-streaming correctness and embeddings.
- **Scheduler/Residency**: Keep-alive, eviction, queue/backpressure not implemented.
- **Observability**: No structured logging/metrics or progress events yet.
