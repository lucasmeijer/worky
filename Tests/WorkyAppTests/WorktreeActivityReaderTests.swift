import XCTest
@testable import WorkyApp

final class WorktreeActivityReaderTests: XCTestCase {
    func testResolvesGitDirFromDotGitFile() throws {
        let tempDir = try TemporaryDirectory()
        let worktreeDir = tempDir.url.appendingPathComponent("wt")
        let gitDir = tempDir.url.appendingPathComponent(".gitdir")
        try FileManager.default.createDirectory(at: worktreeDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let dotGit = worktreeDir.appendingPathComponent(".git")
        try "gitdir: \(gitDir.path)".write(to: dotGit, atomically: true, encoding: .utf8)

        let resolved = try GitDirResolver.resolveGitDir(forWorktreePath: worktreeDir.path)
        XCTAssertEqual(resolved, gitDir.path)
    }

    func testUsesHeadLogMtimeWhenAvailable() throws {
        let tempDir = try TemporaryDirectory()
        let worktreeDir = tempDir.url.appendingPathComponent("wt")
        let gitDir = tempDir.url.appendingPathComponent(".gitdir")
        let logsDir = gitDir.appendingPathComponent("logs")
        let headLog = logsDir.appendingPathComponent("HEAD")
        try FileManager.default.createDirectory(at: worktreeDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        try "gitdir: \(gitDir.path)".write(to: worktreeDir.appendingPathComponent(".git"), atomically: true, encoding: .utf8)
        try "log".write(to: headLog, atomically: true, encoding: .utf8)

        let expected = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: expected], ofItemAtPath: headLog.path)

        let reader = WorktreeActivityReader(fileSystem: LocalFileSystem())
        let actual = try reader.lastActivityDate(forWorktreePath: worktreeDir.path)

        XCTAssertEqual(actual.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }

    func testFallsBackToWorktreeMtime() throws {
        let tempDir = try TemporaryDirectory()
        let worktreeDir = tempDir.url.appendingPathComponent("wt")
        try FileManager.default.createDirectory(at: worktreeDir, withIntermediateDirectories: true)
        let expected = Date(timeIntervalSince1970: 1_700_000_123)
        try FileManager.default.setAttributes([.modificationDate: expected], ofItemAtPath: worktreeDir.path)

        let reader = WorktreeActivityReader(fileSystem: LocalFileSystem())
        let actual = try reader.lastActivityDate(forWorktreePath: worktreeDir.path)

        XCTAssertEqual(actual.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }
}
