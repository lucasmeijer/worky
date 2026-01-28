import Foundation

enum ConfigPaths {
    static var homeConfigDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("git_worktree_manager")
    }
}
