import XCTest
@testable import GWMApp

final class WorktreeStatsReaderTests: XCTestCase {
    func testStatsWithModifiedAndNewFiles() throws {
        let tempDir = try TemporaryDirectory()
        let repoDir = tempDir.url.appendingPathComponent("repo")

        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "--allow-empty", "-m", "init"], in: repoDir)

        // Create initial files
        try "original content 1".write(to: repoDir.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "original content 2".write(to: repoDir.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
        try "will be deleted".write(to: repoDir.appendingPathComponent("file3.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "."], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "add files"], in: repoDir)

        // Modify file1
        try "modified content 1".write(to: repoDir.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)

        // Add new file2 (staged)
        try "new staged content".write(to: repoDir.appendingPathComponent("new_staged.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "new_staged.txt"], in: repoDir)

        // Add untracked file
        try "untracked content".write(to: repoDir.appendingPathComponent("untracked.txt"), atomically: true, encoding: .utf8)

        // Delete file3
        try FileManager.default.removeItem(at: repoDir.appendingPathComponent("file3.txt"))

        let reader = WorktreeStatsReader(runner: LocalProcessRunner())
        let stats = try reader.stats(forWorktreePath: repoDir.path, targetRef: "main")

        // Should count:
        // - file1.txt (modified)
        // - new_staged.txt (new staged)
        // - untracked.txt (new untracked)
        // Total: 3 files added/modified
        XCTAssertEqual(stats.filesAdded, 3, "Should count modified, staged new, and untracked files")

        // Should count:
        // - file3.txt (deleted)
        XCTAssertEqual(stats.filesRemoved, 1, "Should count deleted file")
    }

    func testStatsWithCleanWorktree() throws {
        let tempDir = try TemporaryDirectory()
        let repoDir = tempDir.url.appendingPathComponent("repo")

        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "--allow-empty", "-m", "init"], in: repoDir)

        try "content".write(to: repoDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "."], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "add file"], in: repoDir)

        let reader = WorktreeStatsReader(runner: LocalProcessRunner())
        let stats = try reader.stats(forWorktreePath: repoDir.path, targetRef: "main")

        XCTAssertEqual(stats.filesAdded, 0)
        XCTAssertEqual(stats.filesRemoved, 0)
        XCTAssertTrue(stats.isClean)
    }

    func testStatsWithUnmergedCommits() throws {
        let tempDir = try TemporaryDirectory()
        let repoDir = tempDir.url.appendingPathComponent("repo")

        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "--allow-empty", "-m", "init"], in: repoDir)

        // Create a branch and make some commits
        try runGit(["checkout", "-b", "feature"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "--allow-empty", "-m", "commit1"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "--allow-empty", "-m", "commit2"], in: repoDir)

        let reader = WorktreeStatsReader(runner: LocalProcessRunner())
        let stats = try reader.stats(forWorktreePath: repoDir.path, targetRef: "main")

        XCTAssertEqual(stats.unmergedCommits, 2)
    }

    @discardableResult
    private func runGit(_ args: [String], in directory: URL) throws -> String {
        let runner = LocalProcessRunner()
        let result = try runner.run(["/usr/bin/env", "git"] + args, currentDirectory: directory)
        if result.exitCode != 0 {
            throw NSError(domain: "WorktreeStatsReaderTests", code: 1, userInfo: ["stderr": result.stderr])
        }
        return result.stdout
    }
}
