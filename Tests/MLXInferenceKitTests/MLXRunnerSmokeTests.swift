import XCTest
import Foundation
@testable import MLXInferenceKit

final class MLXRunnerSmokeTests: XCTestCase {
    func testLocalRunnerStreamsMultipleTokens() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let modelPath = tempDir.appendingPathComponent("demo-model.bin")
        FileManager.default.createFile(atPath: modelPath.path, contents: Data(), attributes: nil)

        let modelID = ModelID(name: "demo")
        let runner = LocalMLXRunner(modelPaths: [modelID: modelPath])
        let loaded = try await runner.load(model: modelID, options: ModelLoadOptions())

        let request = GenerationRequest(model: modelID, prompt: "Hello from test")
        var streamedTokens: [String] = []
        var completion: GenerationResult?

        for try await event in runner.generate(request: request, using: loaded) {
            switch event {
            case let .token(token):
                streamedTokens.append(token)
            case let .completed(result):
                completion = result
            }
        }

        XCTAssertGreaterThanOrEqual(streamedTokens.count, 10, "Expected at least 10 tokens streamed")
        XCTAssertFalse(completion?.text.isEmpty ?? true, "Completion text should not be empty")
        XCTAssertEqual(completion?.stats.generatedTokenCount, streamedTokens.count)
    }
}
