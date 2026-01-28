import Foundation

protocol ProjectsConfigStoring {
    var configURL: URL { get }
    func load() throws -> ProjectsConfig
}

protocol GitClienting {
    func listWorktrees(bareRepoPath: String) throws -> [GitWorktreeEntry]
    func addWorktree(bareRepoPath: String, path: String, branchName: String) throws
    func removeWorktree(bareRepoPath: String, path: String) throws
    func resolveGitDir(repoPath: String) throws -> String
}

protocol WorktreeActivityReading {
    func lastActivityDate(forWorktreePath worktreePath: String) throws -> Date
}

struct ProjectItem: Identifiable {
    let id: String
    let name: String
    let repoPath: String
    let gitDirPath: String
    var worktrees: [WorktreeItem]

    init(name: String, repoPath: String, gitDirPath: String, worktrees: [WorktreeItem]) {
        self.id = gitDirPath
        self.name = name
        self.repoPath = repoPath
        self.gitDirPath = gitDirPath
        self.worktrees = worktrees
    }
}

struct WorktreeItem: Identifiable {
    let id: String
    let name: String
    let branchName: String
    let path: String
    let lastActivity: Date
    let buttons: [ResolvedButton]

    init(name: String, branchName: String, path: String, lastActivity: Date, buttons: [ResolvedButton]) {
        self.id = path
        self.name = name
        self.branchName = branchName
        self.path = path
        self.lastActivity = lastActivity
        self.buttons = buttons
    }
}

struct ProjectsLoader {
    let configStore: ProjectsConfigStoring
    let gitClient: GitClienting
    let activityReader: WorktreeActivityReading
    let buttonBuilder: ButtonBuilder
    let pathExpander: (String) -> String
    let isValidGitDir: (String) -> Bool

    init(
        configStore: ProjectsConfigStoring,
        gitClient: GitClienting,
        activityReader: WorktreeActivityReading,
        buttonBuilder: ButtonBuilder,
        pathExpander: @escaping (String) -> String = PathExpander.expand,
        isValidGitDir: @escaping (String) -> Bool = ProjectsLoader.defaultGitDirCheck
    ) {
        self.configStore = configStore
        self.gitClient = gitClient
        self.activityReader = activityReader
        self.buttonBuilder = buttonBuilder
        self.pathExpander = pathExpander
        self.isValidGitDir = isValidGitDir
    }

    func loadProjects() throws -> [ProjectItem] {
        let config = try configStore.load()
        let globalApps = config.apps
        var items: [ProjectItem] = []
        for projectConfig in config.projects {
            let repoPath = pathExpander(projectConfig.bareRepoPath)
            guard let gitDir = try? gitClient.resolveGitDir(repoPath: repoPath) else { continue }
            guard isValidGitDir(gitDir) else { continue }
            let projectName = projectName(from: repoPath)
            do {
                let entries = try gitClient.listWorktrees(bareRepoPath: gitDir)
                let worktrees = entries.map { entry in
                    let name = URL(fileURLWithPath: entry.path).lastPathComponent
                    let branchName = extractBranchName(from: entry.branch)
                    let variables: [String: String] = [
                        "WORKTREE": entry.path,
                        "WORKTREE_NAME": name,
                        "PROJECT": repoPath,
                        "PROJECT_NAME": projectName,
                        "REPO": repoPath
                    ]
                    let buttons = buttonBuilder.build(
                        apps: globalApps + projectConfig.apps,
                        variables: variables
                    )
                    let lastActivity = (try? activityReader.lastActivityDate(forWorktreePath: entry.path)) ?? Date.distantPast
                    return WorktreeItem(name: name, branchName: branchName, path: entry.path, lastActivity: lastActivity, buttons: buttons)
                }
                let sorted = worktrees.sorted { $0.lastActivity > $1.lastActivity }
                items.append(ProjectItem(name: projectName, repoPath: repoPath, gitDirPath: gitDir, worktrees: sorted))
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

    private func extractBranchName(from branch: String?) -> String {
        guard let branch else { return "detached" }
        // Branch format is "refs/heads/branch-name"
        if branch.hasPrefix("refs/heads/") {
            return String(branch.dropFirst("refs/heads/".count))
        }
        return branch
    }

    private static func defaultGitDirCheck(_ path: String) -> Bool {
        let head = URL(fileURLWithPath: path).appendingPathComponent("HEAD").path
        let objects = URL(fileURLWithPath: path).appendingPathComponent("objects").path
        var isDir: ObjCBool = false
        let hasHead = FileManager.default.fileExists(atPath: head)
        let hasObjects = FileManager.default.fileExists(atPath: objects, isDirectory: &isDir)
        return hasHead && hasObjects && isDir.boolValue
    }
}
