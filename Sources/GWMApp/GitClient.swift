import Foundation

struct GitClient: GitClienting {
    let runner: ProcessRunning

    func resolveGitDir(repoPath: String) throws -> String {
        let result = try runner.run([
            "/usr/bin/env",
            "git",
            "-C",
            repoPath,
            "rev-parse",
            "--git-common-dir"
        ], currentDirectory: nil)

        guard result.exitCode == 0 else {
            throw GitClientError.commandFailed(result.stderr)
        }

        let raw = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            throw GitClientError.commandFailed("Empty git dir")
        }
        if raw == "." {
            return normalizePath(repoPath)
        }
        if raw.hasPrefix("/") {
            return normalizePath(raw)
        }
        let resolved = URL(fileURLWithPath: repoPath).appendingPathComponent(raw).path
        return normalizePath(resolved)
    }

    func listWorktrees(bareRepoPath: String) throws -> [GitWorktreeEntry] {
        let result = try runner.run([
            "/usr/bin/env",
            "git",
            "--git-dir",
            bareRepoPath,
            "worktree",
            "list",
            "--porcelain"
        ], currentDirectory: nil)

        guard result.exitCode == 0 else {
            throw GitClientError.commandFailed(result.stderr)
        }

        let normalizedBare = normalizePath(bareRepoPath)
        return GitWorktreeParser.parsePorcelain(result.stdout)
            .filter { normalizePath($0.path) != normalizedBare }
            .filter { !$0.isPrunable }
            .filter { !isMainWorkingDirectory($0.path) }
            .map { entry in
                GitWorktreeEntry(
                    path: normalizePath(entry.path),
                    head: entry.head,
                    branch: entry.branch,
                    isDetached: entry.isDetached,
                    isPrunable: entry.isPrunable
                )
            }
    }

    private func isMainWorkingDirectory(_ path: String) -> Bool {
        // The main working directory has a .git directory (not a file)
        // Worktrees have a .git file that points to the worktree gitdir
        let gitPath = URL(fileURLWithPath: path).appendingPathComponent(".git").path
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func addWorktree(bareRepoPath: String, path: String, branchName: String) throws {
        let result = try runner.run([
            "/usr/bin/env",
            "git",
            "--git-dir",
            bareRepoPath,
            "worktree",
            "add",
            path,
            "-b",
            branchName
        ], currentDirectory: nil)

        guard result.exitCode == 0 else {
            throw GitClientError.commandFailed(result.stderr)
        }
    }

    func removeWorktree(bareRepoPath: String, path: String) throws {
        let result = try runner.run([
            "/usr/bin/env",
            "git",
            "--git-dir",
            bareRepoPath,
            "worktree",
            "remove",
            "--force",
            path
        ], currentDirectory: nil)

        guard result.exitCode == 0 else {
            throw GitClientError.commandFailed(result.stderr)
        }
    }
}

enum GitClientError: Error {
    case commandFailed(String)
}

extension GitClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        }
    }
}

private func normalizePath(_ path: String) -> String {
    URL(fileURLWithPath: path).resolvingSymlinksInPath().path
}
