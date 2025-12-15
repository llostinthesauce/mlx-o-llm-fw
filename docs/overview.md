# MLX-Ollama: Extensive Project Specification
*A local-first, Apple-silicon–optimized model manager + daemon + CLI + SDK built on MLX, designed to be “Ollama-like” in workflow and API while remaining MLX-native.*

> Primary intent: create an **infrastructure product** that other developers can embed or wrap (via SDK or local API daemon), while keeping your existing GUI app as a separate product that consumes the shared core.

---

## 0) Context and Motivation
You want an “Ollama, but for MLX”:

- **Ollama-like user experience**: `pull`, `run`, `chat`, `create` (from a Modelfile-like recipe), local caching, “diff pulls,” and predictable local endpoints.
- **MLX-native runtime**: use **MLX / mlx-lm (or MLX Swift)** as the inference foundation so Apple silicon devices are first-class and performant.
- **Composable platform**: developers can integrate at two levels:
  1) **Embedded Swift SDK** (for macOS/iOS apps)  
  2) **Local HTTP daemon** (OpenAI-compatible + native endpoints) for cross-language wrappers.
- **Separate products**: the platform is its own deliverable; your GUI app is “just another client” built on top.

---

## 1) Product Definition

### 1.1 Deliverables
1. **Core SDK (Swift Package)**: `MLXInferenceKit`
   - Model loading/unloading
   - Tokenization + chat templating
   - Generation and streaming tokens (AsyncSequence)
   - Optional embeddings
2. **Local Daemon (macOS)**: `mlxserve`
   - Always-on model lifecycle owner
   - Native endpoints (Ollama-like)
   - OpenAI-compatible endpoints (`/v1/...`)
   - Scheduler: keep-alive, max loaded models, queue/backpressure
3. **CLI**: `mlxctl`
   - `serve`, `pull`, `list`, `show`, `rm`, `run`, `chat`, `ps`, `stop`, `bench`, `pack`, `push`
4. **Model Store + Registry Layer**: `ModelStoreKit`
   - Content-addressed blobs + manifests
   - Tagging + provenance
   - Garbage collection
   - Registry pull/push via a standard distribution mechanism (recommended: OCI/ORAS)

### 1.2 Integration Modes
- **Embedded Mode (Swift)**: apps directly call `MLXInferenceKit`.
- **Daemon Mode (HTTP)**: tools/apps call `mlxserve` as a local model server.
- **Hybrid Mode**: your GUI app can run embedded by default, with an optional “connect to daemon” mode for parity/testing.

---

## 2) Goals, Non-Goals, and Constraints

### 2.1 Goals
- **Apple silicon performance and ergonomics** with MLX as the inference core.
- **Local-first privacy**: prompts/responses remain local by default; offline inference once models exist.
- **Reproducible model builds**: versioned model packages with pinned upstream sources + checksums.
- **Easy model lifecycle**: `pull/run/create/quantize` single commands with sensible defaults.
- **OpenAI compatibility** for maximum ecosystem leverage.
- **Developer-friendly**: stable APIs, clear contracts, composable modules, robust docs/tests.

### 2.2 Non-Goals (initial milestones)
- Distributed inference / multi-node clusters.
- Training / finetuning beyond optional quantization pipelines.
- Full parity with every Ollama feature on day 1 (multimodal, tool calling can be phased).
- iOS daemon behavior (iOS is embedded-SDK-first due to background/network limitations).

### 2.3 Constraints
- **iOS**: must be SDK-embedded; long-running local servers are not reliable/allowed in typical app lifecycle.
- **macOS**: daemon is feasible and expected.
- **Model format fragmentation** must be controlled via a blessed packaging format.

---

## 3) Market Map (Inference Engines and “What People Use”)
This project focuses on MLX for Apple silicon; however, it helps to place the product in a broader ecosystem:

### 3.1 Major Inference Engines (LLMs)
- **Local/Edge**: llama.cpp / GGUF ecosystem, MLC-LLM, ONNX Runtime GenAI
- **Production GPU Serving**: vLLM, Hugging Face TGI, SGLang, TensorRT-LLM, Triton (platform)
- **Apple Silicon**: MLX + mlx-lm (your chosen baseboard)

### 3.2 “Model managers” vs “Inference engines”
- **Inference engine**: runs the math (MLX runtime here).
- **Model manager**: downloads, caches, versions, exposes APIs (this project’s differentiator).
- **UI**: optional (your GUI app stays separate).

---

## 4) System Architecture (Recommended)

### 4.1 Modules
1. `MLXInferenceKit` (Swift Package)
   - `ModelRunner` protocol (stable interface)
   - `MLXRunner` implementation (MLX Swift)
   - `Tokenizer` subsystem (HF tokenizer files or equivalent)
   - `ChatTemplate` engine
   - `Streaming` primitives (AsyncSequence)
   - `EmbeddingRunner` (phase-gated)
2. `ModelStoreKit` (Swift Package)
   - Content-addressed storage
   - Tag resolution
   - Provenance records
   - GC
   - Registry client abstraction
3. `mlxserve` daemon (macOS)
   - HTTP server (Vapor/SwiftNIO)
   - Scheduler and load/unload policy
   - Native endpoints + OpenAI compatibility
4. `mlxctl` CLI
   - Talks to daemon for lifecycle + run
   - Can also do some local store introspection offline (optional)
5. `Docs/Examples`
   - Example wrappers for Swift, Python, JS
   - Minimal “Hello Local LLM” examples with OpenAI SDK pointing at localhost

### 4.2 Data Flow (Chat Completion)
Client (SDK or HTTP) → Request normalization → Prompt template → Tokenization → MLX generation loop → Stream tokens → Finalize response → Update session state (keep-alive timers, metrics)

---

## 5) “Ollama-like” Parts List (Subsystem-by-Subsystem)
This section itemizes the “things that make Ollama work” as functional units you will implement for MLX.

### 5.1 Daemon / Service Layer
- Always-on local service (`mlxserve`)
- Default bind to **localhost**
- Health/version endpoints
- Model lifecycle ownership (load/unload, caching)
- Request scheduling and backpressure

### 5.2 CLI Surface
- `serve`: start daemon
- `pull`: fetch model packages (with progress)
- `list`: list installed models
- `show`: show details (size, defaults, provenance)
- `rm`: remove tag and optionally blobs
- `run`: one-shot prompt
- `chat`: interactive chat loop
- `create`: build model from recipe (Modelfile-like)
- `ps`: list loaded/running models
- `stop`: unload/stop model sessions
- `bench`: benchmark tokens/sec and memory
- `pack/push`: publish to registry (optional early; can be later milestone)

### 5.3 Model Spec / Build Recipes (“ModelSpec”)
A single-file recipe format analogous to Modelfile to define:
- Base model reference (HF repo + revision OR local path)
- Conversion steps (if needed)
- Quantization settings
- Prompt templates and system prompts
- Default runtime parameters (temperature, top_p, max_tokens, stop)
- Licenses and metadata

Outputs:
- Immutable `manifest.json` (pinned revisions + digests)
- Content-addressed `blobs/` payload

### 5.4 Local Model Store (Content-Addressed)
- `blobs/sha256/<digest>`
- `manifests/<tag>.json` mapping tags to digests
- Tagging semantics:
  - `name:variant@version`
- Garbage collection:
  - delete tag vs delete unreferenced blobs
- Store relocation support via environment/config

### 5.5 Registry Integration
- Pull/push using a blob/manifest protocol.
- Recommended: implement via **OCI artifacts** so you get:
  - content-addressing
  - delta transfers (“diff pulls”)
  - reuse of existing tooling and registries

### 5.6 API Layer
Two surfaces:
- **Native API** (Ollama-like): `/api/generate`, `/api/chat`, `/api/pull`, `/api/create`, `/api/embed`, etc.
- **OpenAI-Compatible API**: `/v1/chat/completions`, `/v1/embeddings`, `/v1/models`

### 5.7 Scheduler + Residency Controls
- `keep_alive` per-request and defaults
- max loaded models
- max queue length (503 on overload)
- max parallel requests per model
- load timeout and idle eviction
- cancellation on disconnect

### 5.8 “Capabilities” Roadmap
- Phase 1: text-only generate/chat + streaming
- Phase 2: embeddings
- Phase 3: tool calling (function calling)
- Phase 4: multimodal image input (as supported by MLX model ecosystems)

---

## 6) Implementation Strategy: Clone-and-Convert vs Ground-Up

### 6.1 Option A — Fork Ollama and Swap Runtime
Pros:
- Fast path to *exact* CLI/API semantics
- Can reuse store/registry logic

Cons:
- Ollama’s codebase/runtime assumptions may be deeply tied to its existing backend.
- Bridging Go runtime ↔ MLX (Swift/Python) adds complexity (FFI/IPC, performance, stability).
- Higher risk of “fighting the architecture.”

### 6.2 Option B — MLX-native Ground-Up (Recommended)
Approach:
- Use MLX/Swift inference as the core.
- Recreate Ollama behavior “from the outside in”:
  - API + CLI + store + registry + build spec

Pros:
- Single cohesive Apple-native stack.
- Faster path to stable inference + good UX.
- More maintainable long-term.

Recommendation:
- **Start MLX-native**, treat Ollama as a behavioral spec and UX benchmark.

---

## 7) Reuse Plan: Libraries / Repos to Leverage
You asked “what can I copy directly?” This project should maximize reuse under permissive licenses (MIT/Apache-2.0), but prefer composition where possible.

### 7.1 Inference Layer
- Use your existing MLX Swift inference logic (already working in GUI).
- Extract into `MLXInferenceKit` as a dependency used by both daemon and GUI app.

### 7.2 API Server Layer
- Accelerate early OpenAI compatibility by borrowing endpoint semantics from existing MLX OpenAI servers
  and porting the contract into Swift (Vapor/SwiftNIO).

### 7.3 Registry / Distribution Layer
- Adopt OCI/ORAS semantics rather than inventing a custom wire protocol.
- Even if you implement push/pull later, model your internal manifests/blobs to be OCI-like from day 1.

### 7.4 Tokenization / Templates
- Decide early:
  - use HF tokenizer assets directly (tokenizer.json, merges, vocab)
  - or use a Swift tokenizer library + cached assets
- Provide template format that can express common chat templates (Llama, Qwen, Gemma, etc.).

---

## 8) Detailed API Specification (Draft)

### 8.1 Native (Ollama-like) API
- `GET /api/version`
- `GET /api/health`
- `GET /api/tags` (installed tags)
- `POST /api/pull` (download package; stream progress)
- `POST /api/push` (optional)
- `POST /api/create` (build from ModelSpec/recipe)
- `POST /api/generate` (prompt → tokens; stream)
- `POST /api/chat` (messages → tokens; stream)
- `POST /api/embed` (text(s) → vectors)
- `POST /api/stop` (stop model session)
- `GET /api/ps` (loaded/running models)

#### 8.1.1 Streaming Format
- Choose one:
  - SSE (OpenAI style)
  - NDJSON line stream
- Must support cancellation and partial output without corrupting daemon state.

### 8.2 OpenAI-Compatible API (Phase 2)
- `GET /v1/models`
- `POST /v1/chat/completions` (stream + non-stream)
- `POST /v1/embeddings`

---

## 9) ModelSpec (Recipe) Format: Requirements

### 9.1 Minimal Fields
- `name`, `version`
- `base`:
  - `hf_repo`, `revision` (pinned) OR
  - local import path
- `format`: `mlx` (blessed); allow future `safetensors` import → convert
- `quantization`: `none/int8/int4/fp16` (as supported by MLX workflows)
- `tokenizer`: local or HF reference
- `prompt_template`: template identifier or inline template
- `defaults`: temperature/top_p/max_tokens/stops/context
- `system_prompt`: optional
- `license`: metadata

### 9.2 Build Outputs
- `manifest.json`:
  - resolved sources
  - digests for every blob
  - build tool versions
  - timestamps
- `blobs/sha256/<digest>`:
  - weights
  - tokenizer assets
  - templates
  - config JSON

### 9.3 Reproducibility Guarantees
- Pinned upstream revision required for “release” tags.
- Full checksums always recorded.
- `mlxctl verify <model>` validates blobs against manifest digests.

---

## 10) Model Store Layout (Draft)
Default root: `~/.mlxollama/`

```
~/.mlxollama/
  blobs/
    sha256/
      <digest>
  manifests/
    <tag>.json
  indexes/
    tags.json
  cache/
    downloads/
  logs/
    daemon.log
  config.json
```

---

## 11) Scheduler and Resource Governance

### 11.1 Residency (“keep alive”)
- Default: 300 seconds
- Request can override: `keep_alive` field
- Idle unload policy: LRU or idle-timeout based

### 11.2 Concurrency
- Global:
  - max active requests
  - max queue length (503 on overflow)
- Per-model:
  - max parallel generations
- Cancellation:
  - on client disconnect or explicit cancel endpoint

### 11.3 Memory Budgeting
- Heuristic estimation:
  - weights size + KV cache estimate
- Configurable cap:
  - if exceeded, evict least-recently-used model sessions

### 11.4 Observability
- Logs: JSONL structured events
- Metrics (optional):
  - active sessions
  - tokens/sec
  - queue depth
  - load/unload times

---

## 12) Desktop GUI App Relationship (Separation of Products)

### 12.1 Extraction Plan
Move these into shared packages:
- inference loop + streaming primitives → `MLXInferenceKit`
- model config parsing + chat templates → `MLXInferenceKit` or `PromptKit`
- model storage and provenance → `ModelStoreKit`

Keep these in GUI app only:
- view models and UI state
- conversation UI/UX
- journaling or app-specific features
- analytics/telemetry (if any; keep separate from platform’s privacy posture)

### 12.2 End-State
- GUI app becomes a premium wrapper/client.
- Platform remains reusable as SDK + daemon.

---

## 13) Milestones and Roadmap

### Milestone 0 — Extraction Spike
- Extract runtime from GUI app into `MLXInferenceKit`.
- Create minimal CLI harness that loads a model and streams tokens.

### Milestone 1 — Daemon MVP
- `mlxserve`:
  - `/api/health`, `/api/version`
  - `/api/generate` (text-only) streaming
- `mlxctl serve` + `mlxctl run`

### Milestone 2 — Store + Tags
- Content-addressed store + manifests.
- CLI: `list/show/rm`.
- Import local artifacts.

### Milestone 3 — Pull + Progress
- Implement `pull` from HTTP catalog/local package.
- Streaming progress updates.
- Delta pulls by digest checking.

### Milestone 4 — OpenAI Compatibility
- `/v1/chat/completions` streaming + non-stream.
- Validate with OpenAI client libraries pointing at localhost.

### Milestone 5 — ModelSpec/Create
- `mlxctl create -f ModelSpec.yaml`
- Build outputs: manifest + blobs.
- `verify` command.

### Milestone 6 — Embeddings + Hardening
- `/api/embed`, `/v1/embeddings`
- Scheduler knobs, integration tests, stability.

### Milestone 7 — Publishing (Optional)
- OCI/ORAS-based push/pull.
- `pack/push`.

---

## 14) Testing Strategy
- Unit: ModelSpec, store, templates
- Integration: pull→run→stream→cancel→unload; OpenAI compatibility
- Perf: tokens/sec, cold vs warm, memory under concurrency

---

## 15) Security and Privacy
- localhost default bind
- explicit opt-in for LAN binding
- offline inference after model installation
- clear documentation for exposure risks

---

## 16) Definition of Done (MVP)
1. `pull` installs at least one model package into the store.
2. `run` streams tokens reliably via daemon.
3. `list/show/rm` function correctly and maintain integrity.
4. OpenAI `/v1/chat/completions` works with standard clients.
5. Offline inference works once model is installed.
6. GUI app consumes `MLXInferenceKit` without importing daemon code.

---

## 17) Immediate Next Actions
1. Extract MLX Swift inference loop → `MLXInferenceKit` with stable `ModelRunner` protocol.
2. Implement `mlxserve` with `/v1/chat/completions` streaming.
3. Implement `ModelStoreKit` (blobs/manifests).
4. Implement `mlxctl pull/list/show/run`.
5. Add ModelSpec/build pipeline.

## Upstream References (Bundled Dependencies)

This repository intentionally vendors a set of **upstream reference repositories** under `./upstream/` to serve as:
- a **behavioral spec** (Ollama semantics: CLI/API/model lifecycle),
- an **implementation reference** (MLX Swift patterns + MLX model workflows),
- and a **distribution reference** (OCI/ORAS blobs/manifests for diff-pulls and publishing).

These upstream repos are included as **git submodules** (preferred) or as plain clones, depending on how you bootstrapped the repo. They are treated as **read-only references** unless explicitly forked.

### What’s in `./upstream/` and why

#### Core behavioral spec (Ollama parity)
- `upstream/ollama`
  - Purpose: Reference for Ollama-style UX and contracts:
    - CLI command surface (`pull`, `run`, `create`, `ps`, `stop`, etc.)
    - API shapes (`/api/*`) and request/streaming conventions
    - Modelfile concepts (model recipes, templating, params)
    - Model store + registry behaviors (tags, manifests, diff pulls)

#### MLX foundation (Apple silicon baseboard)
- `upstream/mlx-swift`
  - Purpose: Ground-truth Swift APIs and patterns for MLX runtime usage on Apple silicon.
- `upstream/mlx-swift-examples`
  - Purpose: Practical patterns for:
    - LLM evaluation/inference flows
    - model/tokenizer download approaches
    - CLI tooling examples in Swift
- `upstream/mlx-lm`
  - Purpose: Reference for MLX model conversion/quantization workflows and HF integration ideas.
  - Note: Even if the platform ships Swift-first, this repo is useful as a “known-good” reference for model workflows.

#### OpenAI-compatible server reference (API semantics)
- `upstream/fastmlx`
  - Purpose: Reference implementation for OpenAI-compatible request/response schemas and streaming behavior in an MLX context.
  - Note: This is a **semantic reference**; the target platform daemon is expected to be Swift-native.

#### Swift tooling reference
- `upstream/swift-argument-parser`
  - Purpose: Best-practice Swift CLI scaffolding patterns for `mlxctl`.

#### OCI / Registry references (diff pulls + publishing)
- `upstream/oci-distribution-spec`
  - Purpose: The distribution protocol spec (pull/push of blobs/manifests).
- `upstream/oci-image-spec`
  - Purpose: The image/manifest structure and media-type conventions (useful for OCI artifacts).
- `upstream/oras-go`
  - Purpose: Reference implementation of OCI artifact push/pull flows.
- `upstream/oras-cli`
  - Purpose: CLI tool for experimenting with OCI registries and validating artifact flows.

### How these are used in this project
- The platform we are building (“MLX-Ollama”) should be **MLX-native**:
  - Inference, streaming, and embedding come from the MLX/Swift stack.
- The Ollama repo is treated as a **contract reference**:
  - We replicate the externally observable behavior (CLI semantics, API shapes, packaging concepts).
- The OCI/ORAS references inform a **content-addressed model store**:
  - blobs + manifests + tags, plus diff-pull/publish workflows.

### Licensing / attribution
Each upstream repo retains its original license. Do not copy code from `./upstream/` into production modules without:
1) verifying the license (MIT/Apache-2.0/etc.),
2) preserving required notices/attribution,
3) and documenting the provenance in commits/headers.

### Quick check: list bundled upstream repos
```bash
ls -1 upstream