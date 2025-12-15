import XCTest
@testable import ModelStoreKit

final class ModelSpecTests: XCTestCase {
    func testDecodesModelSpecFromJSON() throws {
        let json = """
        {
          "name": "llama",
          "version": "v1",
          "base": { "hfRepo": "meta/llama", "revision": "main", "localPath": null },
          "format": "mlx",
          "quantization": "q4",
          "tokenizer": "tokenizer.json",
          "promptTemplate": "llama-chat",
          "defaults": { "temperature": 0.5, "topP": 0.9, "maxTokens": 128, "stop": ["</s>"], "systemPrompt": "You are helpful." },
          "license": "apache-2.0",
          "metadata": { "source": "hf" }
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let spec = try decoder.decode(ModelSpec.self, from: data)
        XCTAssertEqual(spec.name, "llama")
        XCTAssertEqual(spec.version, "v1")
        XCTAssertEqual(spec.base.hfRepo, "meta/llama")
        XCTAssertEqual(spec.defaults?.temperature, 0.5)
        XCTAssertEqual(spec.defaults?.stop, ["</s>"])
        XCTAssertEqual(spec.tag.displayName, "llama:q4@v1")
    }
}
