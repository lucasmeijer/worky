import Foundation

struct WorktreeStats: Equatable {
    let unmergedCommits: Int
    let linesAdded: Int
    let linesRemoved: Int

    var isClean: Bool {
        linesAdded == 0 && linesRemoved == 0
    }

    var unmergedCommitsText: String {
        "\(unmergedCommits) unmerged"
    }

    var lineDeltaText: String {
        isClean ? "clean" : "+\(linesAdded)/-\(linesRemoved)"
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
        let lineStats = try workingCopyLineStats(forWorktreePath: worktreePath)
        return WorktreeStats(
            unmergedCommits: unmergedCommits,
            linesAdded: lineStats.added,
            linesRemoved: lineStats.removed
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

    private func workingCopyLineStats(forWorktreePath worktreePath: String) throws -> (added: Int, removed: Int) {
        let unstaged = try diffStats(command: [
            "/usr/bin/env",
            "git",
            "-C",
            worktreePath,
            "diff",
            "--numstat"
        ])

        let staged = try diffStats(command: [
            "/usr/bin/env",
            "git",
            "-C",
            worktreePath,
            "diff",
            "--cached",
            "--numstat"
        ])

        return (unstaged.added + staged.added, unstaged.removed + staged.removed)
    }

    private func diffStats(command: [String]) throws -> (added: Int, removed: Int) {
        let result = try runner.run(command, currentDirectory: nil)

        guard result.exitCode == 0 else {
            throw WorktreeStatsError.commandFailed(result.stderr)
        }

        var addedTotal = 0
        var removedTotal = 0
        let lines = result.stdout.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            if let added = Int(parts[0]) {
                addedTotal += added
            }
            if let removed = Int(parts[1]) {
                removedTotal += removed
            }
        }
        return (addedTotal, removedTotal)
    }
}

enum WorktreeStatsError: Error {
    case commandFailed(String)
    case unexpectedOutput(String)
}
