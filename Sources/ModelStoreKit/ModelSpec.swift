import Foundation

public struct ModelSpec: Codable, Sendable {
    public struct Base: Codable, Sendable {
        public let hfRepo: String?
        public let revision: String?
        public let localPath: String?

        public init(hfRepo: String? = nil, revision: String? = nil, localPath: String? = nil) {
            self.hfRepo = hfRepo
            self.revision = revision
            self.localPath = localPath
        }
    }

    public struct Defaults: Codable, Sendable {
        public let temperature: Double?
        public let topP: Double?
        public let maxTokens: Int?
        public let stop: [String]?
        public let systemPrompt: String?
    }

    public let name: String
    public let version: String
    public let base: Base
    public let format: String
    public let quantization: String?
    public let tokenizer: String?
    public let promptTemplate: String?
    public let defaults: Defaults?
    public let license: String?
    public let metadata: [String: String]?

    public init(
        name: String,
        version: String,
        base: Base,
        format: String = "mlx",
        quantization: String? = nil,
        tokenizer: String? = nil,
        promptTemplate: String? = nil,
        defaults: Defaults? = nil,
        license: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.name = name
        self.version = version
        self.base = base
        self.format = format
        self.quantization = quantization
        self.tokenizer = tokenizer
        self.promptTemplate = promptTemplate
        self.defaults = defaults
        self.license = license
        self.metadata = metadata
    }

    public var tag: ModelTag {
        ModelTag(name: name, variant: quantization ?? "base", version: version)
    }
}

public enum ModelSpecLoader {
    public static func load(from url: URL) throws -> ModelSpec {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(ModelSpec.self, from: data)
    }
}
