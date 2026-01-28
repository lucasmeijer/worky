import Foundation

struct WorktreeStats: Equatable {
    let unmergedCommits: Int
    let filesAdded: Int
    let filesRemoved: Int

    var isClean: Bool {
        filesAdded == 0 && filesRemoved == 0
    }

    var unmergedCommitsText: String {
        "\(unmergedCommits) unmerged"
    }

    var lineDeltaText: String {
        isClean ? "clean" : "+\(filesAdded)/-\(filesRemoved)"
    }
}

enum WorktreeStatsState: Equatable {
    case loading
    case loaded(WorktreeStats)
    case failed
}

protocol WorktreeStatsReading: Sendable {
    func stats(forWorktreePath worktreePath: String, targetRef: String) throws -> WorktreeStats
}

struct WorktreeStatsReader: WorktreeStatsReading, Sendable {
    let runner: ProcessRunning

    func stats(forWorktreePath worktreePath: String, targetRef: String) throws -> WorktreeStats {
        let unmergedCommits = try unmergedCommits(forWorktreePath: worktreePath, targetRef: targetRef)
        let fileStats = try workingCopyFileStats(forWorktreePath: worktreePath)
        return WorktreeStats(
            unmergedCommits: unmergedCommits,
            filesAdded: fileStats.added,
            filesRemoved: fileStats.removed
        )
    }

    private func unmergedCommits(forWorktreePath worktreePath: String, targetRef: String) throws -> Int {
        let result = try runner.run([
            "/usr/bin/env",
            "git",
            "-C",
            worktreePath,
            "rev-list",
            "--left-right",
            "--count",
            "\(targetRef)...HEAD"
        ], currentDirectory: nil)

        guard result.exitCode == 0 else {
            throw WorktreeStatsError.commandFailed(result.stderr)
        }

        let parts = result.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0 == " " || $0 == "\t" })

        guard parts.count >= 2, let right = Int(parts[1]) else {
            throw WorktreeStatsError.unexpectedOutput(result.stdout)
        }

        return right
    }

    private func workingCopyFileStats(forWorktreePath worktreePath: String) throws -> (added: Int, removed: Int) {
        // Get unstaged changes (modified/deleted files)
        let unstagedFiles = try changedFiles(command: [
            "/usr/bin/env",
            "git",
            "-C",
            worktreePath,
            "diff",
            "--name-status"
        ])

        // Get staged changes (modified/added/deleted files)
        let stagedFiles = try changedFiles(command: [
            "/usr/bin/env",
            "git",
            "-C",
            worktreePath,
            "diff",
            "--cached",
            "--name-status"
        ])

        // Get untracked files
        let untrackedFiles = try untrackedFileCount(worktreePath: worktreePath)

        // Combine results
        let addedModified = unstagedFiles.added + stagedFiles.added + untrackedFiles
        let removed = unstagedFiles.removed + stagedFiles.removed

        return (addedModified, removed)
    }

    private func changedFiles(command: [String]) throws -> (added: Int, removed: Int) {
        let result = try runner.run(command, currentDirectory: nil)

        guard result.exitCode == 0 else {
            throw WorktreeStatsError.commandFailed(result.stderr)
        }

        var addedModified = 0
        var removed = 0
        let lines = result.stdout.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: "\t")
            guard parts.count >= 1 else { continue }
            let status = String(parts[0])
            // M = modified, A = added, D = deleted
            if status == "D" {
                removed += 1
            } else {
                addedModified += 1
            }
        }
        return (addedModified, removed)
    }

    private func untrackedFileCount(worktreePath: String) throws -> Int {
        let result = try runner.run([
            "/usr/bin/env",
            "git",
            "-C",
            worktreePath,
            "ls-files",
            "--others",
            "--exclude-standard"
        ], currentDirectory: nil)

        guard result.exitCode == 0 else {
            throw WorktreeStatsError.commandFailed(result.stderr)
        }

        return result.stdout.split(separator: "\n").filter { !$0.isEmpty }.count
    }
}

enum WorktreeStatsError: Error {
    case commandFailed(String)
    case unexpectedOutput(String)
}
