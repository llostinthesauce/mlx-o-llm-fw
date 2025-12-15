import Foundation

/// Minimal vocab-backed tokenizer: encodes by splitting on whitespace and mapping known tokens to ids,
/// unknown tokens map to a fallback id (0). Decoding concatenates vocab entries by id if present.
public struct VocabTokenizer: Tokenizer {
    private let tokenToId: [String: Int]
    private let idToToken: [Int: String]

    public init(vocab: [String: Int]) {
        self.tokenToId = vocab
        var inverse: [Int: String] = [:]
        for (tok, id) in vocab {
            inverse[id] = tok
        }
        self.idToToken = inverse
    }

    public func encode(_ text: String) throws -> [Int] {
        let parts = text.split(whereSeparator: { $0.isWhitespace })
        return parts.map { tokenToId[String($0)] ?? 0 }
    }

    public func decode(_ tokens: [Int]) throws -> String {
        tokens.compactMap { idToToken[$0] ?? String($0) }.joined(separator: " ")
    }
}
