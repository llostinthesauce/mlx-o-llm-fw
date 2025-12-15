import XCTest
@testable import MLXInferenceKit

final class ModelRunnerTests: XCTestCase {
    func testMockRunnerStreamsTokensAndCompletion() async throws {
        let runner = MockModelRunner(tokens: ["hi", " there"])
        let model = try await runner.load(model: ModelID(name: "demo"), options: ModelLoadOptions())

        let request = GenerationRequest(model: model.id, prompt: "Hello")
        var events: [GenerationEvent] = []

        for try await event in runner.generate(request: request, using: model) {
            events.append(event)
        }

        let tokens = events.compactMap { event -> String? in
            if case let .token(token) = event { return token }
            return nil
        }

        let completion = events.compactMap { event -> GenerationResult? in
            if case let .completed(result) = event { return result }
            return nil
        }.last

        XCTAssertEqual(tokens, ["hi", " there"])
        XCTAssertEqual(completion?.text, "hi there")
        XCTAssertEqual(completion?.stats.generatedTokenCount, 2)
    }

    func testGenerateFailsWhenModelNotLoaded() async {
        let runner = MockModelRunner(tokens: ["hi"])
        let loaded = LoadedModel(id: ModelID(name: "missing"))
        let request = GenerationRequest(model: loaded.id, prompt: "Hello")

        var caught: RunnerError?
        do {
            var iterator = runner.generate(request: request, using: loaded).makeAsyncIterator()
            _ = try await iterator.next()
        } catch let error as RunnerError {
            caught = error
        } catch {
            caught = nil
        }

        XCTAssertEqual(caught, .modelNotLoaded(loaded.id))
    }
}
