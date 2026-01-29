import Foundation
import SwiftUI

struct ProjectViewData: Identifiable {
    let id: String
    let name: String
    let repoPath: String
    let gitDirPath: String
    let worktrees: [WorktreeViewData]
}

struct WorktreeViewData: Identifiable {
    let id: String
    let name: String
    let branchName: String
    let path: String
    let lastActivityText: String
    let statsState: WorktreeStatsState
    let buttons: [ButtonViewData]
    let isMainRepo: Bool

    var stats: WorktreeStats? {
        if case let .loaded(stats) = statsState {
            return stats
        }
        return nil
    }

    var isStatsLoading: Bool {
        if case .loading = statsState { return true }
        return false
    }
}

struct ButtonViewData: Identifiable {
    let id: String
    let label: String
    let icon: IconPayload
    let command: [String]

    var stableId: String { id }

    var swiftUIId: String { id + label }

    var swiftUIImage: Image {
        switch icon.source {
        case .sfSymbol(let name):
            return Image(systemName: name)
        case .appBundle, .file:
            if let image = icon.image {
                return Image(nsImage: image)
            }
            return Image(systemName: "questionmark")
        case .missing:
            return Image(systemName: "questionmark")
        }
    }
}

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published var projects: [ProjectViewData] = []
    @Published var errorMessage: String?
    @Published var busyClaimsByPath: [String: [BusyClaim]] = [:]
    @Published var activeWorktreePath: String?

    var onAppButtonClicked: (() -> Void)?

    private let loader: ProjectsLoader
    private let iconResolver: IconResolver
    private let ghosttyController: GhosttyControlling
    private let commandExecutor: CommandExecuting
    private let gitClient: GitClienting
    private let statsReader: WorktreeStatsReading
    private let branchRenamer: BranchRenameControlling
    private let configStore: ProjectsConfigStoring
    private let busyStore: BusyClaimStore
    private let busyServer: BusyIPCServer
    private let cityPicker: CityNamePicker
    private let worktreeRoot: URL
    private let cityNameSet = Set(CityNames.list)
    private let statsTargetRef = "origin/main"
    private var statsRefreshToken = UUID()
    private var lastGhosttyWorktreePath: String?
    private var renameCandidateToken = UUID()
    @Published var renamingWorktreeIds: Set<String> = []
    @Published var renameCandidateWorktreeIds: Set<String> = []

    init(
        loader: ProjectsLoader,
        iconResolver: IconResolver,
        ghosttyController: GhosttyControlling,
        commandExecutor: CommandExecuting,
        gitClient: GitClienting,
        statsReader: WorktreeStatsReading,
        branchRenamer: BranchRenameControlling,
        configStore: ProjectsConfigStoring,
        busyStore: BusyClaimStore,
        busyServer: BusyIPCServer,
        cityPicker: CityNamePicker = CityNamePicker(),
        worktreeRoot: URL = ConfigPaths.worktreeRoot
    ) {
        self.loader = loader
        self.iconResolver = iconResolver
        self.ghosttyController = ghosttyController
        self.commandExecutor = commandExecutor
        self.gitClient = gitClient
        self.statsReader = statsReader
        self.branchRenamer = branchRenamer
        self.configStore = configStore
        self.busyStore = busyStore
        self.busyServer = busyServer
        self.cityPicker = cityPicker
        self.worktreeRoot = worktreeRoot

        self.busyStore.onUpdate = { [weak self] snapshot in
            self?.busyClaimsByPath = snapshot
        }
        self.busyClaimsByPath = busyStore.snapshot()
    }


    func load() {
        Task { await refresh() }
    }

    func refresh() async {
        errorMessage = nil
        do {
            let items = try loader.loadProjects()
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let now = Date()
            let nextProjects = items.map { project in
                ProjectViewData(
                    id: project.id,
                    name: project.name,
                    repoPath: project.repoPath,
                    gitDirPath: project.gitDirPath,
                    worktrees: project.worktrees.map { worktree in
                        return WorktreeViewData(
                            id: worktree.id,
                            name: worktree.name,
                            branchName: worktree.branchName,
                            path: worktree.path,
                            lastActivityText: formatter.localizedString(for: worktree.lastActivity, relativeTo: now),
                            statsState: .loading,
                            buttons: worktree.buttons.map { button in
                                ButtonViewData(
                                    id: button.id,
                                    label: button.label,
                                    icon: iconResolver.resolve(button.icon),
                                    command: button.command
                                )
                            },
                            isMainRepo: worktree.isMainRepo
                        )
                    }
                )
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                projects = nextProjects
            }
            reconcileActiveWorktreePath()
            refreshStats(for: nextProjects)
        } catch {
            handleError(error)
        }
    }

    func createWorktree(for project: ProjectViewData) {
        Task {
            do {
                print("Worky action: create worktree for \(project.name)")
                let usedNames = Set(project.worktrees.map { $0.name })
                let city = cityPicker.pick(used: usedNames)
                let projectRoot = worktreeRoot.appendingPathComponent(project.name)
                try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
                let worktreePath = projectRoot.appendingPathComponent(city).path
                try gitClient.addWorktree(bareRepoPath: project.gitDirPath, path: worktreePath, branchName: city)
                await refresh()
            } catch {
                handleError(error)
            }
        }
    }

    func removeWorktree(_ worktree: WorktreeViewData, from project: ProjectViewData) {
        Task {
            do {
                print("Worky action: remove worktree \(worktree.path)")
                try gitClient.removeWorktree(bareRepoPath: project.gitDirPath, path: worktree.path)
                await refresh()
            } catch {
                handleError(error)
            }
        }
    }

    func addProject(at path: String) {
        Task {
            do {
                print("Worky action: add project at \(path)")

                // Resolve the git directory (handles both bare repos and worktrees)
                let gitDir = try gitClient.resolveGitDir(repoPath: path)

                // If this is a worktree, gitDir points to .git/worktrees/xxx
                // We need to find the actual bare/main repo
                let repoPath = try findMainRepo(gitDir: gitDir, originalPath: path)

                // Load current config
                var config = try configStore.load()

                // Check if already exists
                let normalizedRepoPath = repoPath.hasPrefix("~") ? repoPath :
                    "~" + repoPath.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "")

                if config.projects.contains(where: { $0.bareRepoPath == normalizedRepoPath }) {
                    print("Worky: Project already exists: \(normalizedRepoPath)")
                    return
                }

                // Detect Rider and solution files
                var projectApps: [AppConfig] = []
                if SolutionFileDetector.isRiderInstalled(),
                   let solutionFile = SolutionFileDetector.findSolutionFile(in: repoPath) {
                    let riderApp = AppConfig(
                        id: "rider",
                        label: "Rider",
                        icon: IconSpec(type: .file, bundleId: nil, path: SolutionFileDetector.riderAppPath, symbol: nil),
                        command: ["open", "-a", "Rider", "$WORKTREE/\(solutionFile)"]
                    )
                    projectApps.append(riderApp)
                    print("Worky: Added Rider app for solution file: \(solutionFile)")
                }

                // Add new project
                config.projects.append(ProjectConfig(bareRepoPath: normalizedRepoPath, apps: projectApps))

                // Save config
                try saveConfig(config)

                // Refresh
                await refresh()
            } catch {
                handleError(error)
            }
        }
    }

    func removeProject(_ project: ProjectViewData) {
        Task {
            do {
                print("Worky action: remove project \(project.name)")

                // Load current config
                var config = try configStore.load()

                // Remove project
                config.projects.removeAll {
                    PathExpander.expand($0.bareRepoPath) == project.repoPath ||
                    $0.bareRepoPath == project.repoPath
                }

                // Save config
                try saveConfig(config)

                // Refresh
                await refresh()
            } catch {
                handleError(error)
            }
        }
    }

    func reorderProjects(_ movingProjects: [ProjectViewData]) {
        guard movingProjects.count == 2,
              let fromProject = movingProjects.first,
              let toProject = movingProjects.last,
              let fromIndex = projects.firstIndex(where: { $0.id == fromProject.id }),
              let toIndex = projects.firstIndex(where: { $0.id == toProject.id }) else {
            return
        }

        // Reorder in UI
        projects.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)

        // Save to config
        Task {
            do {
                var config = try configStore.load()

                // Find config indices by matching repo paths
                guard let configFromIndex = config.projects.firstIndex(where: {
                    PathExpander.expand($0.bareRepoPath) == fromProject.repoPath
                }),
                let configToIndex = config.projects.firstIndex(where: {
                    PathExpander.expand($0.bareRepoPath) == toProject.repoPath
                }) else {
                    return
                }

                // Reorder in config
                let projectToMove = config.projects[configFromIndex]
                config.projects.remove(at: configFromIndex)
                let insertIndex = configToIndex > configFromIndex ? configToIndex : configToIndex
                config.projects.insert(projectToMove, at: insertIndex)

                // Save config
                try saveConfig(config)
            } catch {
                handleError(error)
            }
        }
    }

    private func findMainRepo(gitDir: String, originalPath: String) throws -> String {
        // git rev-parse --git-common-dir returns:
        // - For worktrees: /path/to/repo/.git
        // - For regular repos: /path/to/repo/.git
        // - For bare repos: /path/to/repo.git (or the bare repo path)

        // Strip /.git suffix if present to get the repo root
        if gitDir.hasSuffix("/.git") {
            return String(gitDir.dropLast(5))
        }

        // Otherwise it's a bare repo, return as-is
        return gitDir
    }

    private func saveConfig(_ config: ProjectsConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try FileManager.default.createDirectory(at: configStore.configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: configStore.configURL, options: .atomic)
    }

    func runButton(_ button: ButtonViewData, worktree: WorktreeViewData, project: ProjectViewData) {
        print("Worky action: run button \(button.id) for \(worktree.name)")
        if button.id == "ghostty" {
            ghosttyController.openOrFocus(
                projectName: project.name,
                worktreeName: worktree.name,
                worktreePath: worktree.path
            )
            setActiveWorktreePath(worktree.path)
            onAppButtonClicked?()
            return
        }
        Task {
            do {
                try commandExecutor.execute(button.command)
                onAppButtonClicked?()
            } catch {
                handleError(error)
            }
        }
    }

    func refreshStatsOnActivation() {
        refreshStats(for: projects)
    }

    func refreshActiveWorktreeFromGhostty() {
        setActiveWorktreePath(nil)
        let ghosttyController = self.ghosttyController
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let path = ghosttyController.activeWorktreePath()
            DispatchQueue.main.async {
                self?.setActiveWorktreePath(path)
            }
        }
    }

    func isActiveWorktree(path: String) -> Bool {
        guard let activeWorktreePath else { return false }
        return normalizePath(activeWorktreePath) == normalizePath(path)
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        errorMessage = message
        print("Worky error: \(message)")
    }

    private func setActiveWorktreePath(_ path: String?) {
        lastGhosttyWorktreePath = path
        applyActiveWorktreePath(path)
    }

    private func reconcileActiveWorktreePath() {
        applyActiveWorktreePath(lastGhosttyWorktreePath)
    }

    private func applyActiveWorktreePath(_ path: String?) {
        let managedPaths = Set(projects.flatMap { project in
            project.worktrees.map { normalizePath($0.path) }
        })
        guard let path else {
            activeWorktreePath = nil
            return
        }
        let normalized = normalizePath(path)
        activeWorktreePath = managedPaths.contains(normalized) ? normalized : nil
    }

    private func normalizePath(_ path: String) -> String {
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        guard resolved.count > 1, resolved.hasSuffix("/") else { return resolved }
        return String(resolved.dropLast())
    }

    private func refreshStats(for projects: [ProjectViewData]) {
        let worktrees = projects.flatMap(\.worktrees)
        guard !worktrees.isEmpty else { return }

        setStatsLoading(for: Set(worktrees.map(\.id)))

        let token = UUID()
        statsRefreshToken = token
        let targetRef = statsTargetRef
        let statsReader = self.statsReader
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var results: [String: WorktreeStatsState] = [:]
            for worktree in worktrees {
                do {
                    let stats = try statsReader.stats(forWorktreePath: worktree.path, targetRef: targetRef)
                    results[worktree.id] = .loaded(stats)
                } catch {
                    results[worktree.id] = .failed
                }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.statsRefreshToken == token else { return }
                self.applyStats(results)
            }
        }
    }

    private func setStatsLoading(for worktreeIds: Set<String>) {
        guard !worktreeIds.isEmpty else { return }
        projects = projects.map { project in
            let worktrees = project.worktrees.map { worktree in
                guard worktreeIds.contains(worktree.id) else { return worktree }
                return WorktreeViewData(
                    id: worktree.id,
                    name: worktree.name,
                    branchName: worktree.branchName,
                    path: worktree.path,
                    lastActivityText: worktree.lastActivityText,
                    statsState: .loading,
                    buttons: worktree.buttons,
                    isMainRepo: worktree.isMainRepo
                )
            }
            return ProjectViewData(
                id: project.id,
                name: project.name,
                repoPath: project.repoPath,
                gitDirPath: project.gitDirPath,
                worktrees: worktrees
            )
        }
    }

    private func applyStats(_ statsById: [String: WorktreeStatsState]) {
        guard !statsById.isEmpty else { return }
        projects = projects.map { project in
            let worktrees = project.worktrees.map { worktree in
                guard let statsState = statsById[worktree.id] else { return worktree }
                return WorktreeViewData(
                    id: worktree.id,
                    name: worktree.name,
                    branchName: worktree.branchName,
                    path: worktree.path,
                    lastActivityText: worktree.lastActivityText,
                    statsState: statsState,
                    buttons: worktree.buttons,
                    isMainRepo: worktree.isMainRepo
                )
            }
            return ProjectViewData(
                id: project.id,
                name: project.name,
                repoPath: project.repoPath,
                gitDirPath: project.gitDirPath,
                worktrees: worktrees
            )
        }
        refreshRenameCandidates()
    }

    private func refreshRenameCandidates() {
        let worktrees = projects.flatMap(\.worktrees)
        guard !worktrees.isEmpty else {
            renameCandidateWorktreeIds = []
            return
        }

        let candidates = worktrees.filter { worktree in
            guard let stats = worktree.stats else { return false }
            guard cityNameSet.contains(worktree.branchName.lowercased()) else { return false }
            return stats.unmergedCommits > 0 || !stats.isClean
        }

        guard !candidates.isEmpty else {
            renameCandidateWorktreeIds = []
            return
        }

        let token = UUID()
        renameCandidateToken = token
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var ids = Set<String>()
            for worktree in candidates {
                if !self.branchRenamer.hasUpstreamBranch(forWorktreePath: worktree.path) {
                    ids.insert(worktree.id)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.renameCandidateToken == token else { return }
                self.renameCandidateWorktreeIds = ids
            }
        }
    }

    func renameBranch(for worktree: WorktreeViewData) {
        guard !renamingWorktreeIds.contains(worktree.id) else { return }
        renamingWorktreeIds.insert(worktree.id)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let renamed = self?.branchRenamer.runRenameScript(forWorktreePath: worktree.path) != nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.renamingWorktreeIds.remove(worktree.id)
                if renamed {
                    Task { await self.refresh() }
                }
            }
        }
    }
}
