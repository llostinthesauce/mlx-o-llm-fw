import Foundation

public struct ModelSpecBuildOptions {
    public let artifactPath: URL
    public let tokenizerPath: URL?

    public init(artifactPath: URL, tokenizerPath: URL? = nil) {
        self.artifactPath = artifactPath
        self.tokenizerPath = tokenizerPath
    }
}

public enum ModelSpecBuilderError: Error, Equatable {
    case artifactMissing(URL)
    case tokenizerMissing(URL)
}

/// Builds a manifest from a ModelSpec and imports blobs into a FileModelStore.
public struct ModelSpecBuilder {
    private let store: FileModelStore

    public init(store: FileModelStore) {
        self.store = store
    }

    public func build(spec: ModelSpec, options: ModelSpecBuildOptions) async throws -> ModelManifest {
        let artifactPath = options.artifactPath
        guard FileManager.default.fileExists(atPath: artifactPath.path) else {
            throw ModelSpecBuilderError.artifactMissing(artifactPath)
        }

        let artifactData = try Data(contentsOf: artifactPath)
        let artifactDigest = try await store.importBlob(from: artifactPath)

        var additional: [String: BlobDigest] = [:]

        if let tokenizerPath = options.tokenizerPath {
            guard FileManager.default.fileExists(atPath: tokenizerPath.path) else {
                throw ModelSpecBuilderError.tokenizerMissing(tokenizerPath)
            }
            let tokenizerDigest = try await store.importBlob(from: tokenizerPath)
            additional["tokenizer"] = tokenizerDigest
        }

        var metadata = spec.metadata ?? [:]
        metadata["format"] = spec.format
        if let quant = spec.quantization { metadata["quantization"] = quant }
        if let tokenizer = spec.tokenizer { metadata["tokenizer"] = tokenizer }
        metadata["base_hf_repo"] = spec.base.hfRepo
        metadata["base_revision"] = spec.base.revision
        metadata["base_local_path"] = spec.base.localPath

        let manifest = ModelManifest(
            tag: spec.tag,
            digest: artifactDigest,
            sizeBytes: artifactData.count,
            metadata: metadata,
            additionalBlobs: additional.isEmpty ? nil : additional
        )

        try await store.put(manifest: manifest)
        return manifest
    }
}
