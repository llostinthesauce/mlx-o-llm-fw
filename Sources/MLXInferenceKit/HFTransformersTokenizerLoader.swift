import Foundation
import Tokenizers

public enum HFTransformersTokenizerLoaderError: Error {
    case loadFailed(String)
}

/// Loader that uses huggingface/swift-transformers `AutoTokenizer` to build a real HF tokenizer.
public struct HFTransformersTokenizerLoader: TokenizerLoading {
    public init() {}

    public func loadTokenizer(for modelURL: URL) async throws -> Tokenizer {
        let folder = modelURL.deletingLastPathComponent()
        do {
            let inner = try await AutoTokenizer.from(modelFolder: folder)
            return HFTransformersTokenizer(tokenizer: inner)
        } catch {
            throw HFTransformersTokenizerLoaderError.loadFailed(error.localizedDescription)
        }
    }
}

/// Adapter wrapping the swift-transformers Tokenizer to conform to this module's `Tokenizer` protocol.
public struct HFTransformersTokenizer: MLXInferenceKit.Tokenizer {
    private let inner: Tokenizers.Tokenizer

    public init(tokenizer: Tokenizers.Tokenizer) {
        self.inner = tokenizer
    }

    public func encode(_ text: String) throws -> [Int] {
        inner.encode(text: text)
    }

    public func decode(_ tokens: [Int]) throws -> String {
        inner.decode(tokens: tokens, skipSpecialTokens: false)
    }
}
