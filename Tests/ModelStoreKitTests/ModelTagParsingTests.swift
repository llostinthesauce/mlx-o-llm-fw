import XCTest
@testable import ModelStoreKit

final class ModelTagParsingTests: XCTestCase {
    func testParsesNameVariantVersion() {
        let tag = ModelTag(string: "llama:demo@v1")
        XCTAssertEqual(tag?.name, "llama")
        XCTAssertEqual(tag?.variant, "demo")
        XCTAssertEqual(tag?.version, "v1")
    }

    func testParsesNameAndVersion() {
        let tag = ModelTag(string: "llama@v1")
        XCTAssertEqual(tag?.name, "llama")
        XCTAssertNil(tag?.variant)
        XCTAssertEqual(tag?.version, "v1")
    }

    func testParsesNameOnly() {
        let tag = ModelTag(string: "llama")
        XCTAssertEqual(tag?.name, "llama")
        XCTAssertNil(tag?.variant)
        XCTAssertNil(tag?.version)
    }

    func testRejectsEmpty() {
        let tag = ModelTag(string: "@")
        XCTAssertNil(tag)
    }

    func testDisplayNameRoundTrip() {
        let tag = ModelTag(name: "llama", variant: "demo", version: "v1")
        let parsed = ModelTag(string: tag.displayName)
        XCTAssertEqual(parsed, tag)
    }
}
