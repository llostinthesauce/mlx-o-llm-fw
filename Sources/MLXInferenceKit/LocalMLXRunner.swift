import Foundation

/// Temporary local runner that hardcodes a mapping from ModelID to filesystem paths.
/// Intended as a bridge until a real MLX Swift adapter is wired in.
public final class LocalMLXRunner: ModelRunner {
    private let modelPaths: [ModelID: URL]
    private let tokenDelay: Duration?
    private actor State {
        var loaded: Set<ModelID> = []

        func insert(_ id: ModelID) {
            loaded.insert(id)
        }

        func remove(_ id: ModelID) {
            loaded.remove(id)
        }

        func contains(_ id: ModelID) -> Bool {
            loaded.contains(id)
        }
    }

    private let state = State()

    public init(modelPaths: [ModelID: URL], tokenDelay: Duration? = nil) {
        self.modelPaths = modelPaths
        self.tokenDelay = tokenDelay
    }

    public func load(model: ModelID, options: ModelLoadOptions) async throws -> LoadedModel {
        guard let path = modelPaths[model], FileManager.default.fileExists(atPath: path.path) else {
            throw RunnerError.modelNotLoaded(model)
        }
        await state.insert(model)
        return LoadedModel(id: model)
    }

    public func unload(model: LoadedModel) async {
        await state.remove(model.id)
    }

    public func generate(
        request: GenerationRequest,
        using model: LoadedModel
    ) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let isLoaded = await state.contains(model.id)
                guard isLoaded else {
                    continuation.finish(throwing: RunnerError.modelNotLoaded(model.id))
                    return
                }

                let start = Date()
                var combined = ""
                let tokens = placeholderTokens(for: model.id)

                for token in tokens {
                    if Task.isCancelled {
                        continuation.finish(throwing: RunnerError.cancelled)
                        return
                    }
                    combined.append(token)
                    continuation.yield(.token(token))

                    if let delay = tokenDelay {
                        try? await Task.sleep(for: delay)
                    }
                }

                let stats = GenerationStats(
                    promptTokenCount: request.prompt.split(separator: " ").count,
                    generatedTokenCount: tokens.count,
                    duration: Date().timeIntervalSince(start)
                )
                continuation.yield(.completed(GenerationResult(text: combined, stats: stats)))
                continuation.finish()
            }
        }
    }

    private func placeholderTokens(for model: ModelID) -> [String] {
        let base = "placeholder tokens streaming from \(model.displayName) runner"
        let repeated = Array(repeating: base, count: 2).joined(separator: " ")
        return repeated.split(separator: " ").map(String.init)
    }
}
