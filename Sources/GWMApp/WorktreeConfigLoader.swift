import Foundation

struct WorktreeConfigLoader: WorktreeConfigLoading {
    let fileSystem: FileSystem

    func load(worktreePath: String) throws -> WorktreeConfig {
        let configURL = URL(fileURLWithPath: worktreePath)
            .appendingPathComponent(".config")
            .appendingPathComponent("git_worktree_manager")
            .appendingPathComponent("config.json")

        guard fileSystem.fileExists(at: configURL) else {
            return WorktreeConfig()
        }

        let data = try fileSystem.readFile(at: configURL)
        return try JSONDecoder().decode(WorktreeConfig.self, from: data)
    }
}
