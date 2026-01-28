import XCTest
@testable import GWMApp

final class ButtonBuilderTests: XCTestCase {
    func testMergesDefaultAndConfigButtons() {
        let defaults = [
            ButtonDefinition(id: "ghostty", label: "Ghostty", icon: IconSpec(type: .sfSymbol, bundleId: nil, path: nil, symbol: "terminal"), availability: AvailabilitySpec(bundleId: "ghostty", appName: nil), command: ["open", "$WORKTREE"])
        ]
        let config = [
            ButtonConfig(id: "rider", label: "Rider", icon: nil, availability: nil, command: ["echo", "$WORKTREE_NAME"])
        ]

        let builder = ButtonBuilder(availability: FakeAvailability(availableIds: ["ghostty"]))
        let resolved = builder.build(defaults: defaults, configButtons: config, variables: ["WORKTREE": "/tmp/wt", "WORKTREE_NAME": "oslo"])

        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved[0].label, "Ghostty")
        XCTAssertEqual(resolved[1].label, "Rider")
        XCTAssertEqual(resolved[1].command, ["echo", "oslo"])
    }

    func testDisablesWhenUnavailable() {
        let defaults = [
            ButtonDefinition(id: "ghostty", label: "Ghostty", icon: nil, availability: AvailabilitySpec(bundleId: "ghostty", appName: nil), command: ["open", "$WORKTREE"])
        ]
        let builder = ButtonBuilder(availability: FakeAvailability(availableIds: []))
        let resolved = builder.build(defaults: defaults, configButtons: [], variables: ["WORKTREE": "/tmp/wt"])

        XCTAssertEqual(resolved.count, 1)
        XCTAssertFalse(resolved[0].isEnabled)
    }
}

private struct FakeAvailability: AppAvailabilityChecking {
    let availableIds: Set<String>

    func isAvailable(_ spec: AvailabilitySpec?) -> Bool {
        guard let spec else { return true }
        return availableIds.contains(spec.bundleId)
    }
}
