# ModelSpec Draft (Ollama-like)

Goal: a Modelfile-like recipe that pins upstream sources, defaults, tokenizer/template, and quantization to produce a content-addressed manifest + blobs.

## JSON schema (current)
```jsonc
{
  "name": "llama",
  "version": "v1",
  "base": { "hfRepo": "meta/llama", "revision": "main", "localPath": null },
  "format": "mlx",
  "quantization": "q4",            // optional
  "tokenizer": "tokenizer.json",   // path or HF reference
  "promptTemplate": "llama-chat",  // optional template identifier
  "defaults": {
    "temperature": 0.5,
    "topP": 0.9,
    "maxTokens": 128,
    "stop": ["</s>"],
    "systemPrompt": "You are helpful."
  },
  "license": "apache-2.0",
  "metadata": { "source": "hf" }
}
```

## Mapping to store/runner
- `name`, `version`, `quantization` → `ModelTag`: `name:quantization@version` (variant defaults to `quantization` or `base`).
- `base` → source resolution (HF repo + revision or local path) feeding the MLX conversion/load step.
- `tokenizer` → fed to the tokenizer loader (HF assets).
- `promptTemplate`/`defaults` → seed `GenerationConfig` and templates in `MLXInferenceKit`.
- `manifest` → generated from resolved sources, digests, sizes; stored in `manifests/<tag>.json`.
- `blobs` → weights/tokenizer/config written to `blobs/sha256/<digest>`.

## CLI touchpoints
- `mlxctl spec validate <file>`: validates JSON decodes into ModelSpec.
- `mlxctl spec pack --artifact <file> [--tokenizer <file>] <spec>`: imports blobs into the store and writes `manifests/<tag>.json`.
- Future: `mlxctl create -f <spec>`: builds manifest + blobs, writes to store, imports blob digests.

## Next steps
- Allow YAML input (optional) once a YAML parser is available.
- Add spec → manifest builder that records digests/sizes of resolved artifacts.
- Enforce pinned revisions for “release” tags; record provenance in manifest metadata.
