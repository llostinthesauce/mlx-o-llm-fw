import Foundation

/// Adapter hooks that should be wired to real MLX Swift inference code.
public protocol MLXModelAdapter: Sendable {
    associatedtype Context: Sendable

    func loadModel(id: ModelID, options: ModelLoadOptions) async throws -> Context
    func unloadModel(context: Context) async
    func generate(
        request: GenerationRequest,
        context: Context
    ) -> AsyncThrowingStream<GenerationEvent, Error>
}

/// Default MLX-backed runner placeholder. Plug in a concrete adapter that talks to MLX Swift.
public final class MLXRunner<Adapter: MLXModelAdapter>: ModelRunner {
    public typealias Context = Adapter.Context

    private let adapter: Adapter
    private let state = State()

    private actor State {
        var contexts: [ModelID: Context] = [:]

        func set(_ context: Context, for id: ModelID) {
            contexts[id] = context
        }

        func remove(id: ModelID) -> Context? {
            contexts.removeValue(forKey: id)
        }

        func context(for id: ModelID) -> Context? {
            contexts[id]
        }
    }

    public init(adapter: Adapter) {
        self.adapter = adapter
    }

    public func load(model: ModelID, options: ModelLoadOptions) async throws -> LoadedModel {
        let context = try await adapter.loadModel(id: model, options: options)
        await state.set(context, for: model)
        return LoadedModel(id: model)
    }

    public func unload(model: LoadedModel) async {
        let context = await state.remove(id: model.id)
        guard let ctx = context else { return }
        await adapter.unloadModel(context: ctx)
    }

    public func generate(
        request: GenerationRequest,
        using model: LoadedModel
    ) -> AsyncThrowingStream<GenerationEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard let ctx = await state.context(for: model.id) else {
                    continuation.finish(throwing: RunnerError.modelNotLoaded(model.id))
                    return
                }
                for try await event in adapter.generate(request: request, context: ctx) {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }
}
