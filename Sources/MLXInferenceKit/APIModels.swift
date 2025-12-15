import Foundation
import ModelStoreKit

// MARK: - Native (Ollama-like) requests

public struct OllamaGenerateRequest: Codable, Sendable {
    public let model: String
    public let prompt: String
    public let system: String?
    public let template: String?
    public let stream: Bool?
    public let keepAlive: TimeInterval?
    public let options: OllamaGenerationOptions?
    public let messages: [ChatMessage]?

    public init(
        model: String,
        prompt: String,
        system: String? = nil,
        template: String? = nil,
        stream: Bool? = nil,
        keepAlive: TimeInterval? = nil,
        options: OllamaGenerationOptions? = nil,
        messages: [ChatMessage]? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.system = system
        self.template = template
        self.stream = stream
        self.keepAlive = keepAlive
        self.options = options
        self.messages = messages
    }
}

public struct OllamaGenerationOptions: Codable, Sendable {
    public let temperature: Double?
    public let topP: Double?
    public let maxTokens: Int?
    public let stop: [String]?

    public init(temperature: Double? = nil, topP: Double? = nil, maxTokens: Int? = nil, stop: [String]? = nil) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.stop = stop
    }
}

// MARK: - OpenAI Chat Completions (subset)

public struct OpenAIChatMessage: Codable, Sendable {
    public let role: String
    public let content: String
}

public struct OpenAIChatRequest: Codable, Sendable {
    public let model: String
    public let messages: [OpenAIChatMessage]
    public let temperature: Double?
    public let topP: Double?
    public let maxTokens: Int?
    public let stream: Bool?
    public let stop: [String]?

    public init(
        model: String,
        messages: [OpenAIChatMessage],
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        stream: Bool? = nil,
        stop: [String]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.stream = stream
        self.stop = stop
    }
}

public struct OpenAIChatChunkChoice: Codable, Sendable {
    public let index: Int
    public let delta: OpenAIChatMessage
    public let finishReason: String?
}

public struct OpenAIChatChunk: Codable, Sendable {
    public let id: String
    public let `object`: String
    public let created: Int
    public let model: String
    public let choices: [OpenAIChatChunkChoice]
}

public struct OpenAIChatChoice: Codable, Sendable {
    public let index: Int
    public let message: OpenAIChatMessage
    public let finishReason: String
}

public struct OpenAIUsage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
}

public struct OpenAIChatResponse: Codable, Sendable {
    public let id: String
    public let `object`: String
    public let created: Int
    public let model: String
    public let choices: [OpenAIChatChoice]
    public let usage: OpenAIUsage
}

// MARK: - Pull (local import) API

public struct PullRequest: Codable, Sendable {
    public let tag: String
    public let artifact: String
    public let tokenizer: String?
    public let root: String?
}

// MARK: - Normalization

public enum RequestNormalizer {
    public static func normalize(ollama req: OllamaGenerateRequest) -> GenerationRequest? {
        guard let modelID = ModelTag(string: req.model).map({ ModelID(name: $0.name, variant: $0.variant, version: $0.version) }) else {
            return nil
        }

        let cfg = GenerationConfig(
            maxTokens: req.options?.maxTokens,
            temperature: req.options?.temperature ?? 0.8,
            topP: req.options?.topP ?? 0.95,
            stopSequences: req.options?.stop ?? [],
            presencePenalty: 0,
            frequencyPenalty: 0
        )

        return GenerationRequest(
            model: modelID,
            prompt: req.prompt,
            messages: req.messages ?? [],
            config: cfg,
            systemPrompt: req.system,
            keepAlive: req.keepAlive
        )
    }

    public static func normalize(openAI req: OpenAIChatRequest) -> GenerationRequest? {
        guard let modelID = ModelTag(string: req.model).map({ ModelID(name: $0.name, variant: $0.variant, version: $0.version) }) else {
            return nil
        }

        let messages = req.messages.map { ChatMessage(role: ChatRole(rawValue: $0.role) ?? .user, content: $0.content) }

        let cfg = GenerationConfig(
            maxTokens: req.maxTokens,
            temperature: req.temperature ?? 0.8,
            topP: req.topP ?? 0.95,
            stopSequences: req.stop ?? [],
            presencePenalty: 0,
            frequencyPenalty: 0
        )

        return GenerationRequest(
            model: modelID,
            prompt: "",
            messages: messages,
            config: cfg,
            systemPrompt: nil,
            keepAlive: nil
        )
    }
}
