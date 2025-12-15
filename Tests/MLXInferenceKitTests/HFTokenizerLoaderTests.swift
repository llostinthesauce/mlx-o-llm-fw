import XCTest
@testable import MLXInferenceKit

final class HFTokenizerLoaderTests: XCTestCase {
    func testLoadsTokenizerFromTransformersResources() async throws {
        let resources = URL(fileURLWithPath: "swift-transformers/Tests/TokenizersTests/Resources/tokenizer.json")
        let loader = HFTransformersTokenizerLoader()
        let tokenizer = try await loader.loadTokenizer(for: resources)
        let ids = try tokenizer.encode("Hello world")
        XCTAssertGreaterThan(ids.count, 0)
        let text = try tokenizer.decode(ids)
        XCTAssertFalse(text.isEmpty)
    }
}
