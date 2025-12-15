import XCTest
@testable import ModelStoreKit

final class ModelSpecBuilderTests: XCTestCase {
    func testBuildManifestImportsBlobs() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try FileModelStore(root: tempRoot)
        let builder = ModelSpecBuilder(store: store)

        let artifact = tempRoot.appendingPathComponent("artifact.bin")
        let tokenizer = tempRoot.appendingPathComponent("tokenizer.json")
        FileManager.default.createFile(atPath: artifact.path, contents: Data("artifact".utf8), attributes: nil)
        FileManager.default.createFile(atPath: tokenizer.path, contents: Data("tokenizer".utf8), attributes: nil)

        let spec = ModelSpec(
            name: "llama",
            version: "v1",
            base: .init(hfRepo: "meta/llama", revision: "main", localPath: nil),
            quantization: "q4",
            tokenizer: "tokenizer.json",
            metadata: ["source": "test"]
        )

        let manifest = try await builder.build(
            spec: spec,
            options: ModelSpecBuildOptions(artifactPath: artifact, tokenizerPath: tokenizer)
        )

        XCTAssertEqual(manifest.tag.displayName, "llama:q4@v1")
        XCTAssertNotNil(manifest.additionalBlobs?["tokenizer"])
        let listed = try await store.list()
        XCTAssertEqual(listed.count, 1)
    }
}
