import XCTest
@testable import MLXInferenceKit

final class PromptBuilderTests: XCTestCase {
    func testLlamaTemplateBuildsSections() {
        let messages: [ChatMessage] = [
            .init(role: .system, content: "You are helpful."),
            .init(role: .assistant, content: "Hi, how can I help?"),
            .init(role: .user, content: "Tell me a joke.")
        ]

        let prompt = PromptBuilder.llama(
            systemPrompt: "System override",
            messages: messages,
            userPrompt: "A user prompt"
        )

        XCTAssertTrue(prompt.contains("[SYSTEM_PROMPT]"), "Should include system marker")
        XCTAssertTrue(prompt.contains("System override"), "Should include system override content")
        XCTAssertTrue(prompt.contains("You are helpful."), "Should include system messages")
        XCTAssertTrue(prompt.contains("Tell me a joke."), "Should include user messages")
        XCTAssertTrue(prompt.contains("[ASSISTANT]"), "Should include assistant marker")
        XCTAssertTrue(prompt.contains("Hi, how can I help?"), "Should include assistant messages")
    }
}
