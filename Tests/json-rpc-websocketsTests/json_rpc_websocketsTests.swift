import XCTest
@testable import json_rpc_websockets

final class json_rpc_websocketsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(json_rpc_websockets().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
