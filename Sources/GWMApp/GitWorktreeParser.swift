import Foundation

struct GitWorktreeEntry: Equatable {
    var path: String
    var head: String?
    var branch: String?
    var isDetached: Bool
}

enum GitWorktreeParser {
    static func parsePorcelain(_ output: String) -> [GitWorktreeEntry] {
        var entries: [GitWorktreeEntry] = []
        var current: GitWorktreeEntry?

        func flush() {
            if let entry = current {
                entries.append(entry)
            }
            current = nil
        }

        output.split(separator: "\n", omittingEmptySubsequences: false).forEach { lineSub in
            let line = String(lineSub)
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flush()
                return
            }
            if line.hasPrefix("worktree ") {
                flush()
                let path = line.replacingOccurrences(of: "worktree ", with: "")
                current = GitWorktreeEntry(path: path, head: nil, branch: nil, isDetached: false)
                return
            }
            if line.hasPrefix("HEAD ") {
                current?.head = line.replacingOccurrences(of: "HEAD ", with: "")
                return
            }
            if line.hasPrefix("branch ") {
                current?.branch = line.replacingOccurrences(of: "branch ", with: "")
                return
            }
            if line == "detached" {
                current?.isDetached = true
                return
            }
        }
        flush()
        return entries
    }
}
