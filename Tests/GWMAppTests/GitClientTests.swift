import XCTest
@testable import GWMApp

final class GitClientTests: XCTestCase {
    func testListAddRemoveWorktree() throws {
        let tempDir = try TemporaryDirectory()
        let repoDir = tempDir.url.appendingPathComponent("src")
        let bareDir = tempDir.url.appendingPathComponent("bare.git")
        let worktreeDir = tempDir.url.appendingPathComponent("wt1")

        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoDir)
        try "hello".write(to: repoDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "init"], in: repoDir)
        try runGit(["clone", "--bare", repoDir.path, bareDir.path], in: tempDir.url)

        let client = GitClient(runner: LocalProcessRunner())

        try client.addWorktree(bareRepoPath: bareDir.path, path: worktreeDir.path, branchName: "oslo")
        var worktrees = try client.listWorktrees(bareRepoPath: bareDir.path)
        XCTAssertEqual(worktrees.count, 1)
        XCTAssertEqual(worktrees[0].path, worktreeDir.path)
        XCTAssertEqual(worktrees[0].branch, "refs/heads/oslo")

        try client.removeWorktree(bareRepoPath: bareDir.path, path: worktreeDir.path)
        worktrees = try client.listWorktrees(bareRepoPath: bareDir.path)
        XCTAssertEqual(worktrees.count, 0)
    }

    func testResolveGitDirForBareAndNonBare() throws {
        let tempDir = try TemporaryDirectory()
        let repoDir = tempDir.url.appendingPathComponent("repo")
        let bareDir = tempDir.url.appendingPathComponent("bare.git")

        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        try runGit(["init"], in: repoDir)
        try runGit(["clone", "--bare", repoDir.path, bareDir.path], in: tempDir.url)

        let client = GitClient(runner: LocalProcessRunner())

        let nonBareGitDir = try client.resolveGitDir(repoPath: repoDir.path)
        XCTAssertEqual(nonBareGitDir, repoDir.appendingPathComponent(".git").path)

        let bareGitDir = try client.resolveGitDir(repoPath: bareDir.path)
        XCTAssertEqual(bareGitDir, bareDir.path)
    }

    func testListWorktreesExcludesPrunedWorktrees() throws {
        let tempDir = try TemporaryDirectory()
        let repoDir = tempDir.url.appendingPathComponent("src")
        let bareDir = tempDir.url.appendingPathComponent("bare.git")
        let worktree1Dir = tempDir.url.appendingPathComponent("wt1")
        let worktree2Dir = tempDir.url.appendingPathComponent("wt2")

        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoDir)
        try "hello".write(to: repoDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "init"], in: repoDir)
        try runGit(["clone", "--bare", repoDir.path, bareDir.path], in: tempDir.url)

        let client = GitClient(runner: LocalProcessRunner())

        // Add two worktrees
        try client.addWorktree(bareRepoPath: bareDir.path, path: worktree1Dir.path, branchName: "oslo")
        try client.addWorktree(bareRepoPath: bareDir.path, path: worktree2Dir.path, branchName: "bergen")

        // Verify both are listed
        var worktrees = try client.listWorktrees(bareRepoPath: bareDir.path)
        XCTAssertEqual(worktrees.count, 2)

        // Manually delete one worktree directory to simulate a pruned worktree
        try FileManager.default.removeItem(at: worktree1Dir)

        // List worktrees again - the pruned one should be excluded
        worktrees = try client.listWorktrees(bareRepoPath: bareDir.path)
        XCTAssertEqual(worktrees.count, 1)
        XCTAssertEqual(worktrees[0].path, worktree2Dir.path)
        XCTAssertEqual(worktrees[0].branch, "refs/heads/bergen")
    }

    func testRemoveWorktreeDoesNotLeavePrunableEntry() throws {
        let tempDir = try TemporaryDirectory()
        let repoDir = tempDir.url.appendingPathComponent("src")
        let bareDir = tempDir.url.appendingPathComponent("bare.git")
        let worktreeDir = tempDir.url.appendingPathComponent("wt1")

        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoDir)
        try "hello".write(to: repoDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "init"], in: repoDir)
        try runGit(["clone", "--bare", repoDir.path, bareDir.path], in: tempDir.url)

        let client = GitClient(runner: LocalProcessRunner())

        // Add a worktree
        try client.addWorktree(bareRepoPath: bareDir.path, path: worktreeDir.path, branchName: "oslo")
        var worktrees = try client.listWorktrees(bareRepoPath: bareDir.path)
        XCTAssertEqual(worktrees.count, 1)

        // Remove the worktree using the proper git command
        try client.removeWorktree(bareRepoPath: bareDir.path, path: worktreeDir.path)

        // Verify no worktrees are listed
        worktrees = try client.listWorktrees(bareRepoPath: bareDir.path)
        XCTAssertEqual(worktrees.count, 0)

        // Get raw git output to verify there are no prunable entries
        let rawOutput = try runGit(["--git-dir", bareDir.path, "worktree", "list", "--porcelain"], in: tempDir.url)
        let allEntries = GitWorktreeParser.parsePorcelain(rawOutput)

        // Filter out the bare repo itself using normalized paths (same logic as GitClient)
        let normalizedBare = URL(fileURLWithPath: bareDir.path).resolvingSymlinksInPath().path
        let nonBareEntries = allEntries.filter {
            URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().path != normalizedBare
        }
        XCTAssertEqual(nonBareEntries.count, 0, "Expected no worktree entries after proper removal")

        // Double-check: if any entries exist, none should be prunable
        for entry in nonBareEntries {
            XCTAssertFalse(entry.isPrunable, "Found unexpected prunable entry at \(entry.path)")
        }
    }

    @discardableResult
    private func runGit(_ args: [String], in directory: URL) throws -> String {
        let runner = LocalProcessRunner()
        let result = try runner.run(["/usr/bin/env", "git"] + args, currentDirectory: directory)
        if result.exitCode != 0 {
            throw NSError(domain: "GitClientTests", code: 1, userInfo: ["stderr": result.stderr])
        }
        return result.stdout
    }
}
