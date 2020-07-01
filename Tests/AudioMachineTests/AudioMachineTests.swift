import XCTest
@testable import AudioMachine

final class AudioMachineTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(AudioMachine().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
