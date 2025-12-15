import Foundation
import CryptoKit

public enum BlobStorageError: Error, Equatable {
    case writeFailed(URL, String)
    case mismatch(expected: BlobDigest, actual: String)
    case missing(URL)
}

public struct BlobStorage {
    public let root: URL
    private let fileManager: FileManager

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    public func storeBlob(from source: URL) throws -> BlobDigest {
        guard fileManager.fileExists(atPath: source.path) else {
            throw BlobStorageError.missing(source)
        }
        let data = try Data(contentsOf: source)
        let digestString = Self.sha256Hex(data)
        let digest = BlobDigest(algorithm: .sha256, value: digestString)
        let dest = blobURL(for: digest)
        try ensureParent(of: dest)
        do {
            try data.write(to: dest, options: .atomic)
        } catch {
            throw BlobStorageError.writeFailed(dest, error.localizedDescription)
        }
        return digest
    }

    public func verifyBlob(digest: BlobDigest) throws -> Bool {
        let url = blobURL(for: digest)
        guard fileManager.fileExists(atPath: url.path) else {
            throw BlobStorageError.missing(url)
        }
        let data = try Data(contentsOf: url)
        let actual = Self.sha256Hex(data)
        if actual != digest.value {
            throw BlobStorageError.mismatch(expected: digest, actual: actual)
        }
        return true
    }

    private func blobURL(for digest: BlobDigest) -> URL {
        root.appendingPathComponent("blobs/\(digest.algorithm.rawValue)/\(digest.value)", isDirectory: false)
    }

    private func ensureParent(of url: URL) throws {
        let dir = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private static func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
