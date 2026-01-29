import XCTest
@testable import WorkyApp

final class ProjectsLoaderTests: XCTestCase {
    func testLoadsProjectsSortedByActivity() throws {
        let configStore = InMemoryConfigStore(config: ProjectsConfig(
            apps: [
                AppConfig(id: "ghostty", label: "Ghostty", icon: nil, command: ["open", "$WORKTREE"])
            ],
            projects: [
                ProjectConfig(bareRepoPath: "/tmp/repo.git", apps: [
                    AppConfig(id: "rider", label: "Rider", icon: nil, command: ["echo", "$WORKTREE_NAME"])
                ])
            ],
            dontAutoAdd: ["ghostty", "fork", "vscode"]
        ))
        let gitClient = FakeGitClient(entries: [
            GitWorktreeEntry(path: "/tmp/repo.git/wt1", head: nil, branch: "refs/heads/a", isDetached: false, isPrunable: false, isMainRepo: false),
            GitWorktreeEntry(path: "/tmp/repo.git/wt2", head: nil, branch: "refs/heads/b", isDetached: false, isPrunable: false, isMainRepo: false)
        ])
        let activityReader = FakeActivityReader(dates: [
            "/tmp/repo.git/wt1": Date(timeIntervalSince1970: 100),
            "/tmp/repo.git/wt2": Date(timeIntervalSince1970: 200)
        ])
        let loader = ProjectsLoader(
            configStore: configStore,
            gitClient: gitClient,
            activityReader: activityReader,
            buttonBuilder: ButtonBuilder(),
            isValidGitDir: { _ in true }
        )

        let projects = try loader.loadProjects()

        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].worktrees.count, 2)
        XCTAssertEqual(projects[0].worktrees[0].name, "wt2")
        XCTAssertEqual(projects[0].worktrees[1].name, "wt1")
        XCTAssertEqual(projects[0].worktrees[0].buttons.map { $0.label }, ["Ghostty", "Rider"])
    }
}

private struct InMemoryConfigStore: ProjectsConfigStoring {
    let config: ProjectsConfig
    var configURL: URL { URL(fileURLWithPath: "/dev/null") }
    func load() throws -> ProjectsConfig { config }
}

private struct FakeGitClient: GitClienting {
    let entries: [GitWorktreeEntry]
    func resolveGitDir(repoPath: String) throws -> String { repoPath }
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
