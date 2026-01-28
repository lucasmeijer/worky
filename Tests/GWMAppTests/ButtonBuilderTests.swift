import XCTest
@testable import GWMApp

final class ButtonBuilderTests: XCTestCase {
    func testMergesDefaultAndConfigButtons() {
        let apps = [
            AppConfig(id: "ghostty", label: "Ghostty", icon: IconSpec(type: .sfSymbol, bundleId: nil, path: nil, symbol: "terminal"), command: ["open", "$WORKTREE"]),
            AppConfig(id: "rider", label: "Rider", icon: nil, command: ["echo", "$WORKTREE_NAME"])
        ]

        let builder = ButtonBuilder()
        let resolved = builder.build(apps: apps, variables: ["WORKTREE": "/tmp/wt", "WORKTREE_NAME": "oslo"])

        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved[0].label, "Ghostty")
        XCTAssertEqual(resolved[1].label, "Rider")
        XCTAssertEqual(resolved[1].command, ["echo", "oslo"])
    }
}
