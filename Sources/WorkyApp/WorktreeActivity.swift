import Foundation

enum GitDirResolver {
    static func resolveGitDir(forWorktreePath worktreePath: String) throws -> String {
        let gitPath = URL(fileURLWithPath: worktreePath).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: gitPath.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return gitPath.path
        }

        let data = try Data(contentsOf: gitPath)
        let contents = String(data: data, encoding: .utf8) ?? ""
        let prefix = "gitdir:"
        guard let range = contents.range(of: prefix) else {
            throw WorktreeActivityError.invalidGitDir
        }
        let path = contents[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("/") {
            return path
        }
        let worktreeURL = URL(fileURLWithPath: worktreePath)
        return worktreeURL.appendingPathComponent(path).path
    }
}

struct WorktreeActivityReader: WorktreeActivityReading {
    let fileSystem: FileSystem

    func lastActivityDate(forWorktreePath worktreePath: String) throws -> Date {
        if let gitDir = try? GitDirResolver.resolveGitDir(forWorktreePath: worktreePath) {
            let headLog = URL(fileURLWithPath: gitDir)
                .appendingPathComponent("logs")
                .appendingPathComponent("HEAD")
            if fileSystem.fileExists(at: headLog) {
                return try modificationDate(at: headLog)
            }
        }

        let worktreeURL = URL(fileURLWithPath: worktreePath)
        return try modificationDate(at: worktreeURL)
    }

    private func modificationDate(at url: URL) throws -> Date {
        let attrs = try fileSystem.attributesOfItem(at: url)
        if let date = attrs[.modificationDate] as? Date {
            return date
        }
        throw WorktreeActivityError.missingModificationDate
    }
}

enum WorktreeActivityError: Error {
    case invalidGitDir
    case missingModificationDate
}
