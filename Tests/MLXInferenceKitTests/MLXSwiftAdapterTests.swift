import XCTest
@testable import MLXInferenceKit

final class MLXSwiftAdapterTests: XCTestCase {
    func testLoadFailsWhenPathMissing() async {
        let adapter = MLXSwiftAdapter(modelPaths: [:])
        let runner = MLXRunner(adapter: adapter)
        let modelID = ModelID(name: "missing")

        do {
            _ = try await runner.load(model: modelID, options: ModelLoadOptions())
            XCTFail("Expected missing model to throw")
        } catch let error as MLXSwiftAdapterError {
            XCTAssertEqual(error, .modelPathMissing(modelID))
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testLoadSucceedsAndStreamsPlaceholderTokens() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("mlx-adapter.bin")
        FileManager.default.createFile(atPath: temp.path, contents: Data(), attributes: nil)

        let modelID = ModelID(name: "demo")
        let adapter = MLXSwiftAdapter(
            modelPaths: [modelID: temp],
            placeholderTokens: ["a", "b", "c"],
            tokenizerLoader: DummyTokenizerLoader()
        )
        let runner = MLXRunner(adapter: adapter)

        let loaded = try await runner.load(model: modelID, options: ModelLoadOptions())
        let request = GenerationRequest(model: modelID, prompt: "hi")

        var tokens: [String] = []
        var completion: GenerationResult?

        for try await event in runner.generate(request: request, using: loaded) {
            switch event {
            case let .token(tok): tokens.append(tok)
            case let .completed(res): completion = res
            }
        }

        XCTAssertEqual(tokens, ["a", "b", "c"])
        XCTAssertEqual(completion?.stats.generatedTokenCount, 3)
        XCTAssertEqual(completion?.text, "abc")
    }
}

private struct DummyTokenizerLoader: TokenizerLoading {
    func loadTokenizer(for modelURL: URL) async throws -> Tokenizer {
        VocabTokenizer(vocab: ["hi": 1])
    }
}
