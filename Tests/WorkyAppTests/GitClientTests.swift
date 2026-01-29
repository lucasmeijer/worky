import XCTest
@testable import WorkyApp

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

    func testRemoveWorktreeWithUncommittedChanges() throws {
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

        // Add uncommitted changes
        try "uncommitted".write(to: worktreeDir.appendingPathComponent("new_file.txt"), atomically: true, encoding: .utf8)

        // Should be able to remove even with uncommitted changes (--force flag)
        try client.removeWorktree(bareRepoPath: bareDir.path, path: worktreeDir.path)

        // Verify worktree was removed
        let worktrees = try client.listWorktrees(bareRepoPath: bareDir.path)
        XCTAssertEqual(worktrees.count, 0)
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

    func testListWorktreesIncludesNonBareMainWorkingDirectory() throws {
        let tempDir = try TemporaryDirectory()
        let mainRepoDir = tempDir.url.appendingPathComponent("main-repo")
        let worktree1Dir = tempDir.url.appendingPathComponent("wt1")
        let worktree2Dir = tempDir.url.appendingPathComponent("wt2")

        // Create a normal (non-bare) git repository
        try FileManager.default.createDirectory(at: mainRepoDir, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: mainRepoDir)
        try "initial content".write(to: mainRepoDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: mainRepoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "initial commit"], in: mainRepoDir)

        let client = GitClient(runner: LocalProcessRunner())
        let gitDir = try client.resolveGitDir(repoPath: mainRepoDir.path)

        // Add two worktrees
        try client.addWorktree(bareRepoPath: gitDir, path: worktree1Dir.path, branchName: "feature1")
        try client.addWorktree(bareRepoPath: gitDir, path: worktree2Dir.path, branchName: "feature2")

        // List worktrees - should include all three: the main directory and the two worktrees
        let worktrees = try client.listWorktrees(bareRepoPath: gitDir)

        XCTAssertEqual(worktrees.count, 3, "Should list the main directory plus two worktrees")
        XCTAssertTrue(worktrees.contains { $0.path == worktree1Dir.path }, "Should include feature1 worktree")
        XCTAssertTrue(worktrees.contains { $0.path == worktree2Dir.path }, "Should include feature2 worktree")
        XCTAssertTrue(worktrees.contains { $0.path == mainRepoDir.path }, "Should include the main working directory")

        // Verify the main repo is marked as isMainRepo
        let mainWorktree = worktrees.first { $0.path == mainRepoDir.path }
        XCTAssertNotNil(mainWorktree, "Main worktree should exist")
        XCTAssertTrue(mainWorktree?.isMainRepo ?? false, "Main worktree should have isMainRepo = true")

        // Verify the other worktrees are NOT marked as isMainRepo
        let feature1Worktree = worktrees.first { $0.path == worktree1Dir.path }
        XCTAssertFalse(feature1Worktree?.isMainRepo ?? true, "Feature1 worktree should have isMainRepo = false")

        let feature2Worktree = worktrees.first { $0.path == worktree2Dir.path }
        XCTAssertFalse(feature2Worktree?.isMainRepo ?? true, "Feature2 worktree should have isMainRepo = false")
    }

    func testListWorktreesExcludesBareRepository() throws {
        let tempDir = try TemporaryDirectory()
        let repoDir = tempDir.url.appendingPathComponent("src")
        let bareDir = tempDir.url.appendingPathComponent("bare.git")
        let worktree1Dir = tempDir.url.appendingPathComponent("wt1")
        let worktree2Dir = tempDir.url.appendingPathComponent("wt2")

        // Create a bare repository
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoDir)
        try "hello".write(to: repoDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "init"], in: repoDir)
        try runGit(["clone", "--bare", repoDir.path, bareDir.path], in: tempDir.url)

        let client = GitClient(runner: LocalProcessRunner())

        // Add two worktrees to the bare repository
        try client.addWorktree(bareRepoPath: bareDir.path, path: worktree1Dir.path, branchName: "feature1")
        try client.addWorktree(bareRepoPath: bareDir.path, path: worktree2Dir.path, branchName: "feature2")

        // List worktrees - should only return the two worktrees, not the bare repo itself
        let worktrees = try client.listWorktrees(bareRepoPath: bareDir.path)

        XCTAssertEqual(worktrees.count, 2, "Should only list the two worktrees, not the bare repository")
        XCTAssertTrue(worktrees.contains { $0.path == worktree1Dir.path }, "Should include feature1 worktree")
        XCTAssertTrue(worktrees.contains { $0.path == worktree2Dir.path }, "Should include feature2 worktree")
        XCTAssertFalse(worktrees.contains { $0.path == bareDir.path }, "Should NOT include the bare repository itself")

        // Verify none of the worktrees are marked as isMainRepo (because the repo is bare)
        for worktree in worktrees {
            XCTAssertFalse(worktree.isMainRepo, "Worktrees in a bare repo should not be marked as isMainRepo")
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
