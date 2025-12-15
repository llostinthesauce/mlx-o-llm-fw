import XCTest
@testable import ModelStoreKit

final class ModelStoreTests: XCTestCase {
    func testPutListAndRemoveManifest() async throws {
        let store = InMemoryModelStore()
        let tag = ModelTag(name: "llama", variant: "demo", version: "v1")
        let manifest = ModelManifest(
            tag: tag,
            digest: BlobDigest(value: "abc123"),
            sizeBytes: 42
        )

        try await store.put(manifest: manifest)

        let listed = try await store.list()
        XCTAssertEqual(listed, [manifest])

        let fetched = try await store.manifest(for: tag)
        XCTAssertEqual(fetched, manifest)

        try await store.remove(tag: tag, deleteBlobs: false)
        let missing = try await store.manifest(for: tag)
        XCTAssertNil(missing)
    }

    func testRemoveMissingTagThrows() async {
        let store = InMemoryModelStore()
        let tag = ModelTag(name: "unknown")

        do {
            try await store.remove(tag: tag, deleteBlobs: true)
            XCTFail("Expected removal to throw")
        } catch let error as ModelStoreError {
            XCTAssertEqual(error, .tagNotFound(tag))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
