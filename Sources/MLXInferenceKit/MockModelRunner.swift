import Foundation

public final class MockModelRunner: ModelRunner {
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
    private let tokens: [String]
    private let tokenDelay: Duration?

    public init(tokens: [String] = ["hello", "world"], tokenDelay: Duration? = nil) {
        self.tokens = tokens
        self.tokenDelay = tokenDelay
    }

    public func load(model: ModelID, options: ModelLoadOptions) async throws -> LoadedModel {
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

                var aggregate = ""
                let start = Date()

                for token in tokens {
                    if Task.isCancelled {
                        continuation.finish(throwing: RunnerError.cancelled)
                        return
                    }

                    aggregate.append(token)
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

                continuation.yield(.completed(GenerationResult(text: aggregate, stats: stats)))
                continuation.finish()
            }
        }
    }
}
