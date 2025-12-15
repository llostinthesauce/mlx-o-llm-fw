import Foundation

public enum FileModelStoreError: Error, Equatable {
    case invalidRoot(URL)
    case manifestDecodeFailed(URL, String)
    case writeFailed(URL, String)
}

public final class FileModelStore: ModelStore {
    public let root: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let blobStorage: BlobStorage

    public init(root: URL = FileModelStore.defaultRoot, fileManager: FileManager = .default) throws {
        self.root = root
        self.fileManager = fileManager
        self.blobStorage = BlobStorage(root: root, fileManager: fileManager)
        try ensureLayout()
    }

    public static var defaultRoot: URL {
        if let env = ProcessInfo.processInfo.environment["MLXOLLAMA_HOME"] {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        let home = fileManagerHome()
        return home.appendingPathComponent(".mlxollama", isDirectory: true)
    }

    public func put(manifest: ModelManifest) async throws {
        try ensureLayout()
        let manifestURL = self.manifestURL(for: manifest.tag)
        let data = try encoder.encode(manifest)

        do {
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            throw FileModelStoreError.writeFailed(manifestURL, error.localizedDescription)
        }
    }

    public func manifest(for tag: ModelTag) async throws -> ModelManifest? {
        let url = manifestURL(for: tag)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(ModelManifest.self, from: data)
        } catch {
            throw FileModelStoreError.manifestDecodeFailed(url, error.localizedDescription)
        }
    }

    public func remove(tag: ModelTag, deleteBlobs: Bool) async throws {
        guard let manifest = try await manifest(for: tag) else {
            throw ModelStoreError.tagNotFound(tag)
        }
        let url = manifestURL(for: tag)
        try fileManager.removeItem(at: url)

        if deleteBlobs {
            let blobURL = blobURL(for: manifest.digest)
            if fileManager.fileExists(atPath: blobURL.path) {
                try? fileManager.removeItem(at: blobURL)
            }
        }
    }

    public func list() async throws -> [ModelManifest] {
        try ensureLayout()
        let manifestsDir = root.appendingPathComponent("manifests", isDirectory: true)
        let files = (try? fileManager.contentsOfDirectory(at: manifestsDir, includingPropertiesForKeys: nil)) ?? []
        var results: [ModelManifest] = []

        for file in files where file.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: file)
                let manifest = try decoder.decode(ModelManifest.self, from: data)
                results.append(manifest)
            } catch {
                // skip unreadable manifest
                continue
            }
        }
        return results.sorted { $0.tag.displayName < $1.tag.displayName }
    }

    // MARK: - Blobs

    public func importBlob(from source: URL) async throws -> BlobDigest {
        try blobStorage.storeBlob(from: source)
    }

    public func verify(manifest: ModelManifest) async throws -> Bool {
        _ = try blobStorage.verifyBlob(digest: manifest.digest)
        if let extras = manifest.additionalBlobs {
            for (_, digest) in extras {
                _ = try blobStorage.verifyBlob(digest: digest)
            }
        }
        return true
    }

    private func ensureLayout() throws {
        try createDirectoryIfNeeded(root)
        try createDirectoryIfNeeded(root.appendingPathComponent("blobs/sha256", isDirectory: true))
        try createDirectoryIfNeeded(root.appendingPathComponent("manifests", isDirectory: true))
    }

    private func manifestURL(for tag: ModelTag) -> URL {
        let safeName = sanitize(tag.displayName)
        return root.appendingPathComponent("manifests/\(safeName).json", isDirectory: false)
    }

    private func blobURL(for digest: BlobDigest) -> URL {
        root.appendingPathComponent("blobs/\(digest.algorithm.rawValue)/\(digest.value)", isDirectory: false)
    }

    private func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:@")
        return name.unicodeScalars.map { scalar in
            invalid.contains(scalar) ? "_" : String(scalar)
        }.joined()
    }

    private func createDirectoryIfNeeded(_ url: URL) throws {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue { return }
            throw FileModelStoreError.invalidRoot(url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private func fileManagerHome() -> URL {
    if let path = ProcessInfo.processInfo.environment["HOME"] {
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
}
