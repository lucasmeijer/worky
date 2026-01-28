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
