import Foundation

public struct ModelID: Hashable, Codable, Sendable {
    public let name: String
    public let variant: String?
    public let version: String?

    public init(name: String, variant: String? = nil, version: String? = nil) {
        self.name = name
        self.variant = variant
        self.version = version
    }

    public var displayName: String {
        switch (variant, version) {
        case let (.some(variant), .some(version)):
            return "\(name):\(variant)@\(version)"
        case let (.some(variant), .none):
            return "\(name):\(variant)"
        case let (.none, .some(version)):
            return "\(name)@\(version)"
        default:
            return name
        }
    }
}

public struct ModelLoadOptions: Sendable {
    public var keepAlive: TimeInterval?
    public var eagerLoad: Bool

    public init(keepAlive: TimeInterval? = nil, eagerLoad: Bool = true) {
        self.keepAlive = keepAlive
        self.eagerLoad = eagerLoad
    }
}

public struct LoadedModel: Hashable, Sendable {
    public let id: ModelID
    public let loadedAt: Date

    public init(id: ModelID, loadedAt: Date = Date()) {
        self.id = id
        self.loadedAt = loadedAt
    }
}

public struct GenerationConfig: Equatable, Sendable {
    public var maxTokens: Int?
    public var temperature: Double
    public var topP: Double
    public var stopSequences: [String]
    public var presencePenalty: Double
    public var frequencyPenalty: Double

    public init(
        maxTokens: Int? = 256,
        temperature: Double = 0.8,
        topP: Double = 0.95,
        stopSequences: [String] = [],
        presencePenalty: Double = 0,
        frequencyPenalty: Double = 0
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.stopSequences = stopSequences
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
    }
}

public enum ChatRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

public struct ChatMessage: Codable, Equatable, Sendable {
    public let role: ChatRole
    public let content: String

    public init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
    }
}

public struct GenerationRequest: Sendable {
    public let model: ModelID
    public let prompt: String
    public let messages: [ChatMessage]
    public var config: GenerationConfig
    public var systemPrompt: String?
    public var keepAlive: TimeInterval?

    public init(
        model: ModelID,
        prompt: String,
        messages: [ChatMessage] = [],
        config: GenerationConfig = GenerationConfig(),
        systemPrompt: String? = nil,
        keepAlive: TimeInterval? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.messages = messages
        self.config = config
        self.systemPrompt = systemPrompt
        self.keepAlive = keepAlive
    }
}

public struct GenerationStats: Equatable, Sendable {
    public let promptTokenCount: Int
    public let generatedTokenCount: Int
    public let duration: TimeInterval?
    public let stopHit: Bool

    public init(
        promptTokenCount: Int,
        generatedTokenCount: Int,
        duration: TimeInterval? = nil,
        stopHit: Bool = false
    ) {
        self.promptTokenCount = promptTokenCount
        self.generatedTokenCount = generatedTokenCount
        self.duration = duration
        self.stopHit = stopHit
    }
}

public struct GenerationResult: Equatable, Sendable {
    public let text: String
    public let stats: GenerationStats

    public init(text: String, stats: GenerationStats) {
        self.text = text
        self.stats = stats
    }
}

public enum GenerationEvent: Equatable, Sendable {
    case token(String)
    case completed(GenerationResult)
}

public enum RunnerError: Error, Equatable {
    case modelNotLoaded(ModelID)
    case cancelled
}

public protocol ModelRunner {
    func load(model: ModelID, options: ModelLoadOptions) async throws -> LoadedModel
    func unload(model: LoadedModel) async
    func generate(
        request: GenerationRequest,
        using model: LoadedModel
    ) -> AsyncThrowingStream<GenerationEvent, Error>
}
