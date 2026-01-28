import XCTest
@testable import GWMApp

final class PathExpanderTests: XCTestCase {
    func testExpandsTilde() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let expanded = PathExpander.expand("~/test")
        XCTAssertEqual(expanded, home + "/test")
    }

    func testLeavesAbsolutePath() {
        let input = "/tmp/foo"
        XCTAssertEqual(PathExpander.expand(input), input)
    }
}
