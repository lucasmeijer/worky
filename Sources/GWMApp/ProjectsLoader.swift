import Foundation

protocol ProjectsConfigStoring {
    var configURL: URL { get }
    func load() throws -> ProjectsConfig
}

protocol GitClienting {
    func listWorktrees(bareRepoPath: String) throws -> [GitWorktreeEntry]
    func addWorktree(bareRepoPath: String, path: String, branchName: String) throws
    func removeWorktree(bareRepoPath: String, path: String) throws
}

protocol WorktreeActivityReading {
    func lastActivityDate(forWorktreePath worktreePath: String) throws -> Date
}

protocol WorktreeConfigLoading {
    func load(worktreePath: String) throws -> WorktreeConfig
}

struct ProjectItem: Identifiable {
    let id: UUID
    let name: String
    let bareRepoPath: String
    var worktrees: [WorktreeItem]

    init(name: String, bareRepoPath: String, worktrees: [WorktreeItem]) {
        self.id = UUID()
        self.name = name
        self.bareRepoPath = bareRepoPath
        self.worktrees = worktrees
    }
}

struct WorktreeItem: Identifiable {
    let id: UUID
    let name: String
    let path: String
    let lastActivity: Date
    let buttons: [ResolvedButton]

    init(name: String, path: String, lastActivity: Date, buttons: [ResolvedButton]) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.lastActivity = lastActivity
        self.buttons = buttons
    }
}

struct ProjectsLoader {
    let configStore: ProjectsConfigStoring
    let gitClient: GitClienting
    let activityReader: WorktreeActivityReading
    let worktreeConfigLoader: WorktreeConfigLoading
    let buttonBuilder: ButtonBuilder
    let pathExpander: (String) -> String
    let isValidBareRepo: (String) -> Bool

    init(
        configStore: ProjectsConfigStoring,
        gitClient: GitClienting,
        activityReader: WorktreeActivityReading,
        worktreeConfigLoader: WorktreeConfigLoading,
        buttonBuilder: ButtonBuilder,
        pathExpander: @escaping (String) -> String = PathExpander.expand,
        isValidBareRepo: @escaping (String) -> Bool = ProjectsLoader.defaultBareRepoCheck
    ) {
        self.configStore = configStore
        self.gitClient = gitClient
        self.activityReader = activityReader
        self.worktreeConfigLoader = worktreeConfigLoader
        self.buttonBuilder = buttonBuilder
        self.pathExpander = pathExpander
        self.isValidBareRepo = isValidBareRepo
    }

    func loadProjects() throws -> [ProjectItem] {
        let config = try configStore.load()
        var items: [ProjectItem] = []
        for projectConfig in config.projects {
            let barePath = pathExpander(projectConfig.bareRepoPath)
            guard isValidBareRepo(barePath) else { continue }
            let projectName = projectName(from: barePath)
            do {
                let entries = try gitClient.listWorktrees(bareRepoPath: barePath)
                let worktrees = entries.map { entry in
                    let name = URL(fileURLWithPath: entry.path).lastPathComponent
                    let config = (try? worktreeConfigLoader.load(worktreePath: entry.path)) ?? WorktreeConfig()
                    let variables: [String: String] = [
                        "WORKTREE": entry.path,
                        "WORKTREE_NAME": name,
                        "PROJECT": barePath,
                        "PROJECT_NAME": projectName,
                        "REPO": barePath
                    ]
                    let buttons = buttonBuilder.build(
                        defaults: DefaultButtons.all,
                        configButtons: config.buttons,
                        variables: variables
                    )
                    let lastActivity = (try? activityReader.lastActivityDate(forWorktreePath: entry.path)) ?? Date.distantPast
                    return WorktreeItem(name: name, path: entry.path, lastActivity: lastActivity, buttons: buttons)
                }
                let sorted = worktrees.sorted { $0.lastActivity > $1.lastActivity }
                items.append(ProjectItem(name: projectName, bareRepoPath: barePath, worktrees: sorted))
            } catch {
                print("GWM error: \(error.localizedDescription)")
            }
        }
        return items
    }

    private func projectName(from barePath: String) -> String {
        let url = URL(fileURLWithPath: barePath)
        let name = url.lastPathComponent
        if name.hasSuffix(".git") {
            return String(name.dropLast(4))
        }
        return name
    }

    private static func defaultBareRepoCheck(_ path: String) -> Bool {
        let head = URL(fileURLWithPath: path).appendingPathComponent("HEAD").path
        let objects = URL(fileURLWithPath: path).appendingPathComponent("objects").path
        var isDir: ObjCBool = false
        let hasHead = FileManager.default.fileExists(atPath: head)
        let hasObjects = FileManager.default.fileExists(atPath: objects, isDirectory: &isDir)
        return hasHead && hasObjects && isDir.boolValue
    }
}
