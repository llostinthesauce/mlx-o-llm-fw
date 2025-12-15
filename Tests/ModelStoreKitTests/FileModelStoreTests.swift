import XCTest
@testable import ModelStoreKit

final class FileModelStoreTests: XCTestCase {
    func testPutListShowRemove() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try FileModelStore(root: tempRoot)

        let tag = ModelTag(name: "llama", variant: "demo", version: "v1")
        let manifest = ModelManifest(
            tag: tag,
            digest: BlobDigest(value: "abc123"),
            sizeBytes: 1234
        )

        try await store.put(manifest: manifest)

        let listed = try await store.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.tag, tag)

        let fetched = try await store.manifest(for: tag)
        XCTAssertEqual(fetched, manifest)

        try await store.remove(tag: tag, deleteBlobs: true)
        let missing = try await store.manifest(for: tag)
        XCTAssertNil(missing)
    }

    func testImportAndVerifyBlob() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try FileModelStore(root: tempRoot)

        let source = tempRoot.appendingPathComponent("source.bin")
        let content = "hello blob".data(using: .utf8)!
        FileManager.default.createFile(atPath: source.path, contents: content, attributes: nil)

        let digest = try await store.importBlob(from: source)
        XCTAssertEqual(digest.algorithm, .sha256)

        let manifest = ModelManifest(tag: ModelTag(name: "demo"), digest: digest, sizeBytes: content.count)
        try await store.put(manifest: manifest)

        let verified = try await store.verify(manifest: manifest)
        XCTAssertTrue(verified)
    }

    func testVerifyFailsOnTamperedBlob() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try FileModelStore(root: tempRoot)

        let source = tempRoot.appendingPathComponent("source.bin")
        let content = "hello blob".data(using: .utf8)!
        FileManager.default.createFile(atPath: source.path, contents: content, attributes: nil)

        let digest = try await store.importBlob(from: source)
        let manifest = ModelManifest(tag: ModelTag(name: "demo"), digest: digest, sizeBytes: content.count)
        try await store.put(manifest: manifest)

        // Tamper with stored blob
        let blobPath = tempRoot.appendingPathComponent("blobs/\(digest.algorithm.rawValue)/\(digest.value)")
        FileManager.default.createFile(atPath: blobPath.path, contents: Data("tampered".utf8), attributes: nil)

        do {
            _ = try await store.verify(manifest: manifest)
            XCTFail("Expected verify to throw for tampered blob")
        } catch {
            // expected
        }
    }
}
