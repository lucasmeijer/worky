import Foundation

enum ConfigPaths {
    static var homeConfigDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["GWM_CONFIG_DIR"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: PathExpander.expand(override))
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("git_worktree_manager")
    }

    static var worktreeRoot: URL {
        if let override = ProcessInfo.processInfo.environment["GWM_WORKTREE_ROOT"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: PathExpander.expand(override))
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("gwm")
    }
}
