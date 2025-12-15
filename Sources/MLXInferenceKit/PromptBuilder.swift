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
    /// Builds a prompt for Llama 3 style chat models.
    ///
    /// Template:
    /// <|begin_of_text|><|start_header_id|>system<|end_header_id|>
    ///
    /// {system_prompt}<|eot_id|><|start_header_id|>user<|end_header_id|>
    ///
    /// {user_prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>
    ///
    ///
    public static func llama3(
        systemPrompt: String?,
        messages: [ChatMessage],
        userPrompt: String
    ) -> String {
        var parts: [String] = ["<|begin_of_text|>"]

        // System prompt
        if let system = systemPrompt {
            parts.append("<|start_header_id|>system<|end_header_id|>\n\n\(system)<|eot_id|>")
        }

        // History
        for msg in messages {
            parts.append("<|start_header_id|>\(msg.role.rawValue)<|end_header_id|>\n\n\(msg.content)<|eot_id|>")
        }

        // Current User prompt
        parts.append("<|start_header_id|>user<|end_header_id|>\n\n\(userPrompt)<|eot_id|>")

        // Assistant preamble
        parts.append("<|start_header_id|>assistant<|end_header_id|>\n\n")

        return parts.joined()
    }
}
