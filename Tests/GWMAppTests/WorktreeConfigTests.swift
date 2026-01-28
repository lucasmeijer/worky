import XCTest
@testable import GWMApp

final class WorktreeConfigTests: XCTestCase {
    func testDecodesButtonConfig() throws {
        let json = """
        {
          "buttons": [
            {
              "id": "rider",
              "label": "Rider",
              "icon": { "type": "appBundle", "bundleId": "com.jetbrains.rider" },
              "availability": { "bundleId": "com.jetbrains.rider" },
              "command": ["open", "-a", "Rider.app", "$WORKTREE/Subito/Subito.slnx"]
            }
          ]
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WorktreeConfig.self, from: json)

        XCTAssertEqual(config.buttons.count, 1)
        let button = try XCTUnwrap(config.buttons.first)
        XCTAssertEqual(button.id, "rider")
        XCTAssertEqual(button.label, "Rider")
        XCTAssertEqual(button.command, ["open", "-a", "Rider.app", "$WORKTREE/Subito/Subito.slnx"])
        XCTAssertEqual(button.icon?.type, .appBundle)
        XCTAssertEqual(button.icon?.bundleId, "com.jetbrains.rider")
        XCTAssertEqual(button.availability?.bundleId, "com.jetbrains.rider")
    }

    func testDecodesMinimalButtonConfig() throws {
        let json = """
        { "buttons": [ { "label": "Foo", "command": ["echo", "hi"] } ] }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WorktreeConfig.self, from: json)
        let button = try XCTUnwrap(config.buttons.first)
        XCTAssertEqual(button.label, "Foo")
        XCTAssertEqual(button.command, ["echo", "hi"])
        XCTAssertNil(button.icon)
        XCTAssertNil(button.availability)
    }
}
