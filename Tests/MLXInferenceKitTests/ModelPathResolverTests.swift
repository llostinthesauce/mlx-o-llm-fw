import XCTest
@testable import MLXInferenceKit

final class ModelPathResolverTests: XCTestCase {
    func testLoadsMappingsFromJSON() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let content = """
        [
          { "name": "demo", "variant": "base", "version": "v1", "path": "/tmp/demo.bin" },
          { "name": "alt", "path": "/tmp/alt.bin" }
        ]
        """
        try content.write(to: temp, atomically: true, encoding: .utf8)

        let mapping = try ModelPathResolver.load(from: temp)
        XCTAssertEqual(mapping.count, 2)
        XCTAssertEqual(mapping[ModelID(name: "demo", variant: "base", version: "v1")]?.path, "/tmp/demo.bin")
        XCTAssertEqual(mapping[ModelID(name: "alt")]?.path, "/tmp/alt.bin")
    }

    func testMissingFileThrows() {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).json")
        XCTAssertThrowsError(try ModelPathResolver.load(from: missing)) { error in
            XCTAssertEqual(error as? ModelPathResolverError, .fileNotFound(missing))
        }
    }
}
