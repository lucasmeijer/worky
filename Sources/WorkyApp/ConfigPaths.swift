import Foundation

enum ConfigPaths {
    static var homeConfigDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["WORKY_CONFIG_DIR"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: PathExpander.expand(override))
        }
        if let override = ProcessInfo.processInfo.environment["GWM_CONFIG_DIR"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: PathExpander.expand(override))
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".worky")
            .appendingPathComponent("config")
    }

    static var worktreeRoot: URL {
        if let override = ProcessInfo.processInfo.environment["WORKY_WORKTREE_ROOT"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: PathExpander.expand(override))
        }
        if let override = ProcessInfo.processInfo.environment["GWM_WORKTREE_ROOT"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: PathExpander.expand(override))
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".worky")
    }

    static var ipcSocketURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".worky")
            .appendingPathComponent("run")
            .appendingPathComponent("worky.sock")
    }
}
