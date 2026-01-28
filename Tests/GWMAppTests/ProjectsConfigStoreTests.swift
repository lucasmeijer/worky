import XCTest
@testable import GWMApp

final class ProjectsConfigStoreTests: XCTestCase {
    func testCreatesDefaultConfigWhenMissing() throws {
        let tempDir = try TemporaryDirectory()
        let store = ProjectsConfigStore(
            baseDirectory: tempDir.url,
            fileSystem: LocalFileSystem()
        )

        let config = try store.load()

        XCTAssertTrue(config.projects.isEmpty)
        XCTAssertTrue(config.apps.isEmpty)
        let stored = try Data(contentsOf: store.configURL)
        XCTAssertFalse(stored.isEmpty)
    }

    func testLoadsExistingConfig() throws {
        let tempDir = try TemporaryDirectory()
        let store = ProjectsConfigStore(
            baseDirectory: tempDir.url,
            fileSystem: LocalFileSystem()
        )
        let custom = ProjectsConfig(
            apps: [AppConfig(id: "ghostty", label: "Ghostty", icon: nil, command: ["open"])],
            projects: [ProjectConfig(bareRepoPath: "~/custom")]
        )
        let data = try JSONEncoder().encode(custom)
        try data.write(to: store.configURL, options: .atomic)

        let loaded = try store.load()

        XCTAssertEqual(loaded.projects.map { $0.bareRepoPath }, ["~/custom"])
        XCTAssertEqual(loaded.apps.map { $0.id ?? "" }, ["ghostty"])
    }
}

final class TemporaryDirectory {
    let url: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory
        url = base.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
