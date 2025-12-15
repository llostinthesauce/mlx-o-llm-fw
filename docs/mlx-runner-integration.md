# MLX Runner Integration Guide

Purpose: replace the placeholder/Local/Mock runners with a real MLX Swift-backed adapter for one known-good model so we can stream real tokens end-to-end.

## What exists
- `MLXRunner` wraps any `MLXModelAdapter`.
- `MLXSwiftAdapter` is a stub: validates model path, optionally loads a tokenizer, and emits placeholder tokens.
- `PromptBuilder` provides a simple Llama-style template.
- `ModelPathResolver` loads ModelID → URL mappings from JSON (see `config/model-paths.example.json`).
- `mlx-demo` CLI supports `--runner local` + `--model-paths-json` to target local models.

## What to wire up
1) **Tokenizer loader (HF assets)**  
   Implement `TokenizerLoading` that reads `tokenizer.json` + merges/vocab next to the model and returns a concrete `Tokenizer` (wrap an existing HF-compatible Swift tokenizer if you have one, or port a minimal BPE). Plug it into `MLXSwiftAdapter(tokenizerLoader:)`.

2) **Model load**  
   In `MLXSwiftAdapter.loadModel`, replace the placeholder with your MLX Swift load:
   - Load weights/config from `modelURL`.
   - Prepare chat template defaults if needed.
   - Store any loaded handles in `Context` (e.g., model graph, kv-cache buffers, tokenizer).

3) **Generation loop**  
   In `MLXSwiftAdapter.generate`:
   - Build the prompt via `PromptBuilder.llama(...)` (or another template).
   - Tokenize input with the tokenizer.
   - Run MLX generation with streaming callbacks.
   - Decode tokens incrementally to text and `yield .token(decodedChunk)`.
   - On finish, compute `GenerationStats` and `yield .completed(...)`.
   - Honor cancellation (`Task.isCancelled`) to abort MLX generation cleanly.

4) **Model path mapping**  
   Copy `config/model-paths.example.json` → `config/model-paths.local.json` and fill your real model path. Pass to `mlx-demo --runner local --model-paths-json config/model-paths.local.json --prompt "hi"`.

## Smoke test sequence (after wiring)
1) `scripts/swift-test-local.sh` (repo-local caches).  
2) `swift run mlx-demo --runner local --model-paths-json config/model-paths.local.json --prompt "Hello"`.  
   - Expect streamed tokens and a final `[done]` with token count.

## Example adapter pseudocode (swap into MLXSwiftAdapter)
```swift
public func loadModel(id: ModelID, options: ModelLoadOptions) async throws -> Context {
    guard let url = modelPaths[id] else { throw MLXSwiftAdapterError.modelPathMissing(id) }
    let tokenizer = try await tokenizerLoader?.loadTokenizer(for: url)

    // Pseudocode: replace with your MLX Swift load
    let weights = try MLXModel.load(from: url)          // your existing loader
    let generator = try MLXGenerator(model: weights)    // e.g., initializes KV cache, device

    return Context(id: id, modelURL: url, tokenizer: tokenizer, generator: generator)
}

public func generate(request: GenerationRequest, context: Context) -> AsyncThrowingStream<GenerationEvent, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                let prompt = PromptBuilder.llama(
                    systemPrompt: request.systemPrompt,
                    messages: request.messages,
                    userPrompt: request.prompt
                )
                let inputIds = try context.tokenizer?.encode(prompt) ?? []

                try await context.generator.generate(
                    input: inputIds,
                    config: request.config,
                    onToken: { tokenId in
                        // decode incrementally
                        let piece = try context.tokenizer?.decode([tokenId]) ?? ""
                        continuation.yield(.token(piece))
                        if Task.isCancelled { throw RunnerError.cancelled }
                    }
                )

                // on completion
                let stats = GenerationStats(
                    promptTokenCount: inputIds.count,
                    generatedTokenCount: context.generator.generatedCount,
                    duration: context.generator.lastDuration
                )
                let text = try context.tokenizer?.decode(context.generator.generatedTokens) ?? ""
                continuation.yield(.completed(GenerationResult(text: text, stats: stats)))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
```
Adjust names to your actual MLX Swift API; key is: tokenize → generate with streaming callback → decode per token → yield events → emit stats.

## Notes / future
- Once the real MLX runner streams correctly, proceed to daemon scaffolding (`mlxserve` with `/api/health` and `/api/generate`).
- Keep `MockModelRunner` for CI and fast unit tests; use `LocalMLXRunner` only for interim local smoke tests if needed.

## Tie-back to scope doc (`docs/overview.md`)
- This fulfills Milestone 0 (“Extraction Spike”) by moving the GUI’s MLX inference into `MLXInferenceKit` with a stable `ModelRunner`.
- Unblocks Milestone 1 by providing the runner needed for `/api/generate` and `mlxctl run`.
- Lays groundwork for ModelSpec/templates by ensuring prompt building and tokenization paths exist in one place.

### Scope-aligned checklist (runner-specific)
- [ ] Extract GUI MLX inference loop into `MLXSwiftAdapter` → `MLXRunner` (Milestone 0, Immediate Next Actions #1).
- [ ] Validate streaming with one local model using `mlx-demo --runner local` (Milestone 0 acceptance).
- [ ] Expose runner through daemon `/api/generate` + `mlxctl run` once streaming is correct (Milestone 1 linkage).

### Where this sits in the original spec (quick map)
- **Section 4.1 Modules:** This work completes the `ModelRunner` piece inside `MLXInferenceKit`.
- **Section 5.1 / 5.2 (Daemon + CLI):** Real runner is prerequisite for `/api/generate` and `mlxctl run/chat`.
- **Milestone 0 (Extraction Spike):** This is the core deliverable for that milestone.
- **Milestone 1 (Daemon MVP):** Needs the real runner to satisfy `/api/generate` streaming.

### Helpers added in repo for integration
- `ModelPathResolver` + `config/model-paths.example.json`: map ModelID → local model file.
- `HFTransformersTokenizerLoader`: wraps huggingface/swift-transformers AutoTokenizer to load real HF tokenizers from local model folders.
- `PromptBuilder.llama`: simple template to build the prompt before tokenization.
- `mlx-demo --runner local`: CLI to stream tokens from a local model mapping (defaults to `config/model-paths.local.json` if present).
- `FileModelStore` + `mlxctl store list/show/rm/import/verify`: offline store management mirroring Ollama-like blobs/manifests.
- `mlxctl run`: quick one-off runner invocation (mock/local) for smoke tests.
