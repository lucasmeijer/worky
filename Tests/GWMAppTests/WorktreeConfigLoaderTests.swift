import XCTest
@testable import GWMApp

final class WorktreeConfigLoaderTests: XCTestCase {
    func testLoadsConfigWhenPresent() throws {
        let tempDir = try TemporaryDirectory()
        let worktree = tempDir.url.appendingPathComponent("wt")
        let configDir = worktree.appendingPathComponent(".config/git_worktree_manager")
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let configURL = configDir.appendingPathComponent("config.json")
        let payload = WorktreeConfig(buttons: [ButtonConfig(id: "a", label: "A", icon: nil, availability: nil, command: ["echo"])])
        let data = try JSONEncoder().encode(payload)
        try data.write(to: configURL)

        let loader = WorktreeConfigLoader(fileSystem: LocalFileSystem())
        let loaded = try loader.load(worktreePath: worktree.path)

        XCTAssertEqual(loaded.buttons.count, 1)
        XCTAssertEqual(loaded.buttons.first?.label, "A")
    }

    func testReturnsEmptyWhenMissing() throws {
        let tempDir = try TemporaryDirectory()
        let worktree = tempDir.url.appendingPathComponent("wt")
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)

        let loader = WorktreeConfigLoader(fileSystem: LocalFileSystem())
        let loaded = try loader.load(worktreePath: worktree.path)

        XCTAssertEqual(loaded.buttons.count, 0)
    }
}
