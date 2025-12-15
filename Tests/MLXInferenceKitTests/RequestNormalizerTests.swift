import XCTest
@testable import MLXInferenceKit

final class RequestNormalizerTests: XCTestCase {
    func testNormalizeOllamaRequest() {
        let req = OllamaGenerateRequest(
            model: "llama:demo@v1",
            prompt: "hi",
            system: "sys",
            stream: true,
            keepAlive: 60,
            options: OllamaGenerationOptions(temperature: 0.5, topP: 0.9, maxTokens: 42, stop: ["stop"]),
            messages: [ChatMessage(role: .user, content: "hello")]
        )

        let normalized = RequestNormalizer.normalize(ollama: req)
        XCTAssertEqual(normalized?.model.name, "llama")
        XCTAssertEqual(normalized?.model.variant, "demo")
        XCTAssertEqual(normalized?.model.version, "v1")
        XCTAssertEqual(normalized?.prompt, "hi")
        XCTAssertEqual(normalized?.systemPrompt, "sys")
        XCTAssertEqual(normalized?.keepAlive, 60)
        XCTAssertEqual(normalized?.config.maxTokens, 42)
        XCTAssertEqual(normalized?.config.temperature, 0.5)
        XCTAssertEqual(normalized?.config.topP, 0.9)
        XCTAssertEqual(normalized?.config.stopSequences, ["stop"])
    }

    func testNormalizeOpenAIRequest() {
        let req = OpenAIChatRequest(
            model: "llama",
            messages: [OpenAIChatMessage(role: "user", content: "hi")],
            temperature: 0.7,
            topP: 0.8,
            maxTokens: 64,
            stream: true,
            stop: ["stop"]
        )

        let normalized = RequestNormalizer.normalize(openAI: req)
        XCTAssertEqual(normalized?.model.name, "llama")
        XCTAssertEqual(normalized?.config.temperature, 0.7)
        XCTAssertEqual(normalized?.config.topP, 0.8)
        XCTAssertEqual(normalized?.config.maxTokens, 64)
        XCTAssertEqual(normalized?.config.stopSequences, ["stop"])
        XCTAssertEqual(normalized?.messages.first?.content, "hi")
    }
}
