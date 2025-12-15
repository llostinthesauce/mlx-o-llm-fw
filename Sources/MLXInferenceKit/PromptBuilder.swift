import Foundation

/// Minimal chat prompt builder with a Llama-style template.
public enum PromptBuilder {
    /// Builds a prompt for Llama-style chat models.
    ///
    /// Template (roughly):
    ///
    /// ```
    /// <s>[SYSTEM_PROMPT]</s>
    /// [USER_PROMPT]
    /// [ASSISTANT_PREFIX]
    /// ```
    ///
    /// Messages are flattened by role; system messages are concatenated, user/assistant messages
    /// are appended in order. This is intentionally simple and can be replaced with richer templates later.
    public static func llama(
        systemPrompt: String?,
        messages: [ChatMessage],
        userPrompt: String
    ) -> String {
        var parts: [String] = []

        let systemMessages = messages.filter { $0.role == .system }.map(\.content)
        let userMessages = messages.filter { $0.role == .user }.map(\.content)
        let assistantMessages = messages.filter { $0.role == .assistant }.map(\.content)

        let systemBlock = ([systemPrompt].compactMap { $0 } + systemMessages)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !systemBlock.isEmpty {
            parts.append("<s>[SYSTEM_PROMPT]\n\(systemBlock)\n</s>")
        }

        if !userMessages.isEmpty {
            parts.append(userMessages.joined(separator: "\n"))
        }

        parts.append(userPrompt)

        if !assistantMessages.isEmpty {
            parts.append("[ASSISTANT]\n\(assistantMessages.joined(separator: "\n"))")
        }

        return parts.joined(separator: "\n\n")
    }
}
