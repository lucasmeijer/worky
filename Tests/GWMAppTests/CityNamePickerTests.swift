import XCTest
@testable import GWMApp

final class CityNamePickerTests: XCTestCase {
    func testPicksUnusedName() {
        let picker = CityNamePicker(names: ["oslo", "porto"]) { _ in 0 }
        let result = picker.pick(used: ["porto"])
        XCTAssertEqual(result, "oslo")
    }

    func testAddsSuffixWhenAllUsed() {
        let picker = CityNamePicker(names: ["oslo"]) { _ in 0 }
        let result = picker.pick(used: ["oslo", "oslo-2"])
        XCTAssertEqual(result, "oslo-3")
    }
}
