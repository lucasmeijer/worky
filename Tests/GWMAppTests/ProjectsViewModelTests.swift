import XCTest
import AppKit
@testable import GWMApp

@MainActor
final class ProjectsViewModelTests: XCTestCase {
    func testRefreshLoadsProjects() async {
        let configStore = InMemoryConfigStore(config: ProjectsConfig(
            apps: [
                AppConfig(id: "ghostty", label: "Ghostty", icon: nil, command: ["open", "$WORKTREE"])
            ],
            projects: [
                ProjectConfig(bareRepoPath: "/tmp/repo.git", apps: [
                    AppConfig(id: "rider", label: "Rider", icon: nil, command: ["echo", "$WORKTREE_NAME"])
                ])
            ]
        ))
        let gitClient = FakeGitClient(entries: [
            GitWorktreeEntry(path: "/tmp/repo.git/wt1", head: nil, branch: "refs/heads/a", isDetached: false)
        ])
        let activityReader = FakeActivityReader(dates: [
            "/tmp/repo.git/wt1": Date(timeIntervalSince1970: 100)
        ])
        let loader = ProjectsLoader(
            configStore: configStore,
            gitClient: gitClient,
            activityReader: activityReader,
            buttonBuilder: ButtonBuilder(),
            isValidGitDir: { _ in true }
        )

        let viewModel = ProjectsViewModel(
            loader: loader,
            iconResolver: IconResolver(
                appProvider: FakeAppProvider(),
                fileLoader: FakeFileLoader(),
                symbolProvider: FakeSymbolProvider()
            ),
            ghosttyController: FakeGhosttyController(),
            commandExecutor: FakeCommandExecutor(),
            gitClient: gitClient,
            cityPicker: CityNamePicker(names: ["oslo"], randomIndex: { _ in 0 })
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.projects.count, 1)
        XCTAssertEqual(viewModel.projects[0].worktrees.count, 1)
    }
}

private struct FakeGhosttyController: GhosttyControlling {
    func openOrFocus(projectName: String, worktreeName: String, worktreePath: String) {}
}

private struct FakeCommandExecutor: CommandExecuting {
    func execute(_ command: [String]) throws {}
}

private struct FakeAppProvider: AppIconProviding {
    func icon(forBundleId bundleId: String) -> NSImage? { NSImage() }
}

private struct FakeFileLoader: FileImageLoading {
    func loadImage(at path: String) -> NSImage? { NSImage() }
}

private struct FakeSymbolProvider: SymbolImageProviding {
    func symbolImage(name: String) -> NSImage? { NSImage() }
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
