import XCTest
@testable import GWMApp

final class ProjectsLoaderTests: XCTestCase {
    func testLoadsProjectsSortedByActivity() throws {
        let configStore = InMemoryConfigStore(config: ProjectsConfig(projects: [
            ProjectConfig(bareRepoPath: "/tmp/repo.git")
        ]))
        let gitClient = FakeGitClient(entries: [
            GitWorktreeEntry(path: "/tmp/repo.git/wt1", head: nil, branch: "refs/heads/a", isDetached: false),
            GitWorktreeEntry(path: "/tmp/repo.git/wt2", head: nil, branch: "refs/heads/b", isDetached: false)
        ])
        let activityReader = FakeActivityReader(dates: [
            "/tmp/repo.git/wt1": Date(timeIntervalSince1970: 100),
            "/tmp/repo.git/wt2": Date(timeIntervalSince1970: 200)
        ])
        let loader = ProjectsLoader(
            configStore: configStore,
            gitClient: gitClient,
            activityReader: activityReader,
            worktreeConfigLoader: FakeWorktreeConfigLoader(),
            buttonBuilder: ButtonBuilder(availability: FakeAvailability(availableIds: [])),
            isValidBareRepo: { _ in true }
        )

        let projects = try loader.loadProjects()

        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].worktrees.count, 2)
        XCTAssertEqual(projects[0].worktrees[0].name, "wt2")
        XCTAssertEqual(projects[0].worktrees[1].name, "wt1")
    }
}

private struct InMemoryConfigStore: ProjectsConfigStoring {
    let config: ProjectsConfig
    var configURL: URL { URL(fileURLWithPath: "/dev/null") }
    func load() throws -> ProjectsConfig { config }
}

private struct FakeGitClient: GitClienting {
    let entries: [GitWorktreeEntry]
    func listWorktrees(bareRepoPath: String) throws -> [GitWorktreeEntry] { entries }
    func addWorktree(bareRepoPath: String, path: String, branchName: String) throws {}
    func removeWorktree(bareRepoPath: String, path: String) throws {}
}

private struct FakeActivityReader: WorktreeActivityReading {
    let dates: [String: Date]
    func lastActivityDate(forWorktreePath worktreePath: String) throws -> Date {
        dates[worktreePath] ?? Date()
    }
}

private struct FakeWorktreeConfigLoader: WorktreeConfigLoading {
    func load(worktreePath: String) throws -> WorktreeConfig { WorktreeConfig() }
}

private struct FakeAvailability: AppAvailabilityChecking {
    let availableIds: Set<String>
    func isAvailable(_ spec: AvailabilitySpec?) -> Bool {
        guard let spec else { return true }
        return availableIds.contains(spec.bundleId)
    }
}
