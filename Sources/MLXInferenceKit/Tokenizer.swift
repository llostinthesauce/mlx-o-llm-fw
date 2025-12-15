import Foundation

public protocol Tokenizer: Sendable {
    func encode(_ text: String) throws -> [Int]
    func decode(_ tokens: [Int]) throws -> String
}

public protocol TokenizerLoading: Sendable {
    func loadTokenizer(for modelURL: URL) async throws -> Tokenizer
}

/// Placeholder tokenizer that splits on whitespace; replace with HF asset-based implementation.
public struct WhitespaceTokenizer: Tokenizer {
    public init() {}

    public func encode(_ text: String) throws -> [Int] {
        text.split(separator: " ").map { _ in Int.random(in: 1...1000) }
    }

    public func decode(_ tokens: [Int]) throws -> String {
        tokens.map { "\($0)" }.joined(separator: " ")
    }
}
