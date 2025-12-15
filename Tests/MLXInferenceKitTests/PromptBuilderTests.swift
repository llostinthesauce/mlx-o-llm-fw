import XCTest
@testable import MLXInferenceKit

final class PromptBuilderTests: XCTestCase {
    func testLlamaTemplateBuildsSections() {
        let messages: [ChatMessage] = [
            .init(role: .system, content: "You are helpful."),
            .init(role: .assistant, content: "Hi, how can I help?"),
            .init(role: .user, content: "Tell me a joke.")
        ]

        let prompt = PromptBuilder.llama3(
            systemPrompt: "System override",
            messages: messages,
            userPrompt: "A user prompt"
        )

        XCTAssertTrue(prompt.contains("<|begin_of_text|>"), "Should include start marker")
        XCTAssertTrue(prompt.contains("<|start_header_id|>system<|end_header_id|>"), "Should include system header")
        XCTAssertTrue(prompt.contains("System override"), "Should include system override content")
        XCTAssertTrue(prompt.contains("You are helpful."), "Should include system messages")
        XCTAssertTrue(prompt.contains("Tell me a joke."), "Should include user messages")
        XCTAssertTrue(prompt.contains("<|start_header_id|>assistant<|end_header_id|>"), "Should include assistant header")
        XCTAssertTrue(prompt.contains("Hi, how can I help?"), "Should include assistant messages")
    }
}
