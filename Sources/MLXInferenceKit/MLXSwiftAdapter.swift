import Foundation
import MLXLMCommon

public enum MLXSwiftAdapterError: Error, Equatable {
    case unavailable(String)
    case modelPathMissing(ModelID)
    case tokenizerUnavailable
    case tokenizerLoadFailed(String)
}

/// Skeleton adapter intended to wrap real MLX Swift inference.
/// This currently acts as a shim: it validates a known model path and can emit placeholder tokens
/// so the runner contract holds even when MLX is not yet wired. Replace the placeholder
/// implementation with actual MLX generation logic from the GUI app.
public struct MLXSwiftAdapter: MLXModelAdapter {
    /// Backend for actual generation. Default keeps placeholder behavior for tests/CI.
    public enum Backend: @unchecked Sendable {
        case placeholder
        case python(PythonMLXLmRunner)
        case nativeSwift
    }

    private actor ContainerCache {
        var containers: [ModelID: ModelContainer] = [:]

        func cached(_ id: ModelID) -> ModelContainer? {
            containers[id]
        }

        func store(_ id: ModelID, container: ModelContainer) {
            containers[id] = container
        }

        func remove(_ id: ModelID) {
            containers.removeValue(forKey: id)
        }
    }

    public struct Context: Sendable {
        public let id: ModelID
        public let modelURL: URL
        public let tokenizer: Tokenizer?
        public let backend: Backend
        public let pythonLoadedModel: LoadedModel?
        public let nativeContainer: ModelContainer?
    }

    private let modelPaths: [ModelID: URL]
    private let placeholderTokens: [String]
    private let tokenizerLoader: TokenizerLoading?
    private let backend: Backend
    private let cache = ContainerCache()

    public init(
        modelPaths: [ModelID: URL],
        placeholderTokens: [String] = ["mlx", " adapter", " not", " wired"],
        tokenizerLoader: TokenizerLoading? = HFTransformersTokenizerLoader(),
        backend: Backend = .placeholder
    ) {
        self.modelPaths = modelPaths
        self.placeholderTokens = placeholderTokens
        self.tokenizerLoader = tokenizerLoader
        self.backend = backend
    }

    public func loadModel(id: ModelID, options: ModelLoadOptions) async throws -> Context {
        guard let url = modelPaths[id], FileManager.default.fileExists(atPath: url.path) else {
            throw MLXSwiftAdapterError.modelPathMissing(id)
        }

        var tokenizer: Tokenizer?
        if let loader = tokenizerLoader {
            do {
                tokenizer = try await loader.loadTokenizer(for: url)
            } catch {
                // If we are using a backend that does not need Swift-side tokenization, allow nil.
                if case .python = backend {
                    tokenizer = nil
                } else if case .nativeSwift = backend {
                    tokenizer = nil
                } else {
                    throw MLXSwiftAdapterError.tokenizerLoadFailed(String(describing: error))
                }
            }
        } else if case .placeholder = backend {
            throw MLXSwiftAdapterError.tokenizerUnavailable
        }

        switch backend {
        case .placeholder:
            return Context(id: id, modelURL: url, tokenizer: tokenizer, backend: backend, pythonLoadedModel: nil, nativeContainer: nil)
        case let .python(pythonRunner):
            let loaded = try await pythonRunner.load(model: id, options: options)
            return Context(id: id, modelURL: url, tokenizer: tokenizer, backend: backend, pythonLoadedModel: loaded, nativeContainer: nil)
        case .nativeSwift:
            if let existing = await cache.cached(id) {
                return Context(id: id, modelURL: url, tokenizer: tokenizer, backend: backend, pythonLoadedModel: nil, nativeContainer: existing)
            }
            let container = try await loadModelContainer(directory: url)
            await cache.store(id, container: container)
            return Context(id: id, modelURL: url, tokenizer: tokenizer, backend: backend, pythonLoadedModel: nil, nativeContainer: container)
        }
    }

    public func unloadModel(context: Context) async {
        switch context.backend {
        case .placeholder:
            break
        case let .python(pythonRunner):
            if let loaded = context.pythonLoadedModel {
                await pythonRunner.unload(model: loaded)
            }
        case .nativeSwift:
            await cache.remove(context.id)
        }
    }

    public func generate(
        request: GenerationRequest,
        context: Context
    ) -> AsyncThrowingStream<GenerationEvent, Error> {
        let promptText = PromptBuilder.llama(
            systemPrompt: request.systemPrompt,
            messages: request.messages,
            userPrompt: request.prompt
        )

        let templatedRequest = GenerationRequest(
            model: request.model,
            prompt: promptText,
            messages: request.messages,
            config: request.config,
            systemPrompt: request.systemPrompt,
            keepAlive: request.keepAlive
        )

        switch context.backend {
        case .placeholder:
            return placeholderStream(request: templatedRequest, context: context)
        case let .python(pythonRunner):
            guard let loaded = context.pythonLoadedModel else {
                return AsyncThrowingStream { continuation in
                    continuation.finish(throwing: RunnerError.modelNotLoaded(request.model))
                }
            }
            return pythonRunner.generate(request: templatedRequest, using: loaded)
        case .nativeSwift:
            return nativeSwiftStream(request: request, context: context)
        }
    }

    private func placeholderStream(
        request: GenerationRequest,
        context: Context
    ) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let tokens: [String]
                if !placeholderTokens.isEmpty {
                    tokens = placeholderTokens
                } else {
                    if let tokenizer = context.tokenizer {
                        do {
                            let encoded = try tokenizer.encode(request.prompt)
                            tokens = try encoded.map { try tokenizer.decode([$0]) }
                        } catch {
                            tokens = request.prompt.split(separator: " ").map(String.init)
                        }
                    } else {
                        tokens = request.prompt.split(separator: " ").map(String.init)
                    }
                }

                var combined = ""
                let start = Date()

                for token in tokens {
                    if Task.isCancelled {
                        continuation.finish(throwing: RunnerError.cancelled)
                        return
                    }
                    combined.append(token + " ")
                    continuation.yield(.token(token))
                }

                let stats = GenerationStats(
                    promptTokenCount: tokens.count,
                    generatedTokenCount: tokens.count,
                    duration: Date().timeIntervalSince(start)
                )
                continuation.yield(.completed(GenerationResult(text: combined.trimmingCharacters(in: .whitespaces), stats: stats)))
                continuation.finish()
            }
        }
    }

    private func nativeSwiftStream(
        request: GenerationRequest,
        context: Context
    ) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let container = context.nativeContainer else {
                    continuation.finish(throwing: RunnerError.modelNotLoaded(request.model))
                    return
                }

                do {
                    var collected = ""
                    var tokenCount = 0
                    var info: MLXLMCommon.GenerateCompletionInfo?
                    let stopSequences = request.config.stopSequences
                    let start = Date()
                    let parameters = GenerateParameters(
                        maxTokens: request.config.maxTokens,
                        temperature: Float(request.config.temperature),
                        topP: Float(request.config.topP),
                        repetitionPenalty: repetitionPenalty(from: request.config),
                        repetitionContextSize: 128
                    )

                    let chatMessages = buildChatMessages(systemPrompt: request.systemPrompt, history: request.messages, userPrompt: request.prompt)

                    try await container.perform { (ctx: ModelContext) async throws -> Void in
                        let userInput = UserInput(chat: chatMessages)
                        let input = try await ctx.processor.prepare(input: userInput)
                        let cache = ctx.model.newCache(parameters: parameters)

                        let stream = try MLXLMCommon.generate(
                            input: input,
                            cache: cache,
                            parameters: parameters,
                            context: ctx
                        )

                        var stopHit = false
                        for await event in stream {
                            if Task.isCancelled {
                                break
                            }
                            switch event {
                            case .chunk(let text):
                                let candidate = collected + text
                                if let trimmed = trimStopSequence(from: candidate, stops: stopSequences) {
                                    collected = trimmed
                                    stopHit = true
                                    break
                                }
                                collected = candidate
                                tokenCount += 1
                                continuation.yield(.token(text))
                            case .toolCall:
                                // tool calls are not surfaced in this adapter yet
                                break
                            case .info(let completion):
                                info = completion
                            }
                            if stopHit { break }
                        }
                    }

                    let stats = GenerationStats(
                        promptTokenCount: info?.promptTokenCount ?? chatMessages.reduce(into: 0) { $0 += $1.content.split(separator: " ").count },
                        generatedTokenCount: info?.generationTokenCount ?? tokenCount,
                        duration: info.map { $0.promptTime + $0.generateTime } ?? Date().timeIntervalSince(start),
                        stopHit: stopHit
                    )
                    continuation.yield(.completed(GenerationResult(text: collected, stats: stats)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildChatMessages(
        systemPrompt: String?,
        history: [ChatMessage],
        userPrompt: String
    ) -> [MLXLMCommon.Chat.Message] {
        var messages: [MLXLMCommon.Chat.Message] = []
        if let systemPrompt {
            messages.append(.system(systemPrompt))
        }
        for msg in history {
            switch msg.role {
            case .system:
                messages.append(.system(msg.content))
            case .assistant:
                messages.append(.assistant(msg.content))
            case .user:
                messages.append(.user(msg.content))
            }
        }
        messages.append(.user(userPrompt))
        return messages
    }

    private func trimStopSequence(from text: String, stops: [String]) -> String? {
        guard !stops.isEmpty else { return nil }
        for stop in stops where !stop.isEmpty {
            if text.hasSuffix(stop) {
                return String(text.dropLast(stop.count))
            }
        }
        return nil
    }

    private func repetitionPenalty(from config: GenerationConfig) -> Float? {
        let penalty = max(config.presencePenalty, config.frequencyPenalty)
        return penalty > 0 ? Float(penalty) : nil
    }
}
