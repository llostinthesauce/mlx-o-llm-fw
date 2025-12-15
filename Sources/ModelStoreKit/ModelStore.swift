import Foundation

public struct ModelTag: Hashable, Codable, Sendable {
    public let name: String
    public let variant: String?
    public let version: String?

    public init?(string: String) {
        let parts = string.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        let left = parts.first.map(String.init) ?? string
        let version = parts.count > 1 ? String(parts[1]) : nil

        let nameVariant = left.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let base = nameVariant.first, !base.isEmpty else { return nil }
        let variant = nameVariant.count > 1 ? String(nameVariant[1]) : nil

        self.name = String(base)
        self.variant = variant?.isEmpty == true ? nil : variant
        self.version = version?.isEmpty == true ? nil : version
    }

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

public struct BlobDigest: Hashable, Codable, Sendable {
    public enum Algorithm: String, Codable, Sendable {
        case sha256
    }

    public let algorithm: Algorithm
    public let value: String

    public init(algorithm: Algorithm = .sha256, value: String) {
        self.algorithm = algorithm
        self.value = value
    }
}

public struct ModelManifest: Equatable, Codable, Sendable {
    public let tag: ModelTag
    public let digest: BlobDigest
    public let sizeBytes: Int
    public let createdAt: Date
    public let metadata: [String: String]
    public let additionalBlobs: [String: BlobDigest]?

    public init(
        tag: ModelTag,
        digest: BlobDigest,
        sizeBytes: Int,
        createdAt: Date = Date(),
        metadata: [String: String] = [:],
        additionalBlobs: [String: BlobDigest]? = nil
    ) {
        self.tag = tag
        self.digest = digest
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
        self.metadata = metadata
        self.additionalBlobs = additionalBlobs
    }
}

public enum ModelStoreError: Error, Equatable {
    case tagNotFound(ModelTag)
}

public protocol ModelStore {
    func put(manifest: ModelManifest) async throws
    func manifest(for tag: ModelTag) async throws -> ModelManifest?
    func remove(tag: ModelTag, deleteBlobs: Bool) async throws
    func list() async throws -> [ModelManifest]
    func verify(manifest: ModelManifest) async throws -> Bool
}

public actor InMemoryModelStore: ModelStore {
    private var manifests: [ModelTag: ModelManifest] = [:]

    public init() {}

    public func put(manifest: ModelManifest) async throws {
        manifests[manifest.tag] = manifest
    }

    public func manifest(for tag: ModelTag) async throws -> ModelManifest? {
        manifests[tag]
    }

    public func remove(tag: ModelTag, deleteBlobs: Bool) async throws {
        guard manifests.removeValue(forKey: tag) != nil else {
            throw ModelStoreError.tagNotFound(tag)
        }
    }

    public func list() async throws -> [ModelManifest] {
        manifests.values.sorted { $0.tag.displayName < $1.tag.displayName }
    }

    public func verify(manifest: ModelManifest) async throws -> Bool {
        // No blob backing; assume true for in-memory usage.
        return manifests[manifest.tag] != nil
    }
}
