import XCTest
@testable import WorkyApp

final class BranchRenameScriptTests: XCTestCase {
    func testRenameScriptRenamesBranchFromDiff() throws {
        let tempDir = try TemporaryDirectory()
        let repoDir = tempDir.url.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)

        try runGit(["init", "-b", "main"], in: repoDir)
        try "hello".write(to: repoDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "init"], in: repoDir)
        try runGit(["checkout", "-b", "oslo"], in: repoDir)

        try "work in progress".write(to: repoDir.appendingPathComponent("README.md"), atomically: false, encoding: .utf8)

        let stubDir = tempDir.url.appendingPathComponent("stub")
        try FileManager.default.createDirectory(at: stubDir, withIntermediateDirectories: true)
        let stubPath = stubDir.appendingPathComponent("claude")
        let stubScript = """
        #!/bin/bash
        set -euo pipefail
        input=$(cat)
        if [[ -z \"$input\" ]]; then
          echo "no"
          exit 0
        fi
        echo "feature-from-diff"
        """
        try stubScript.write(to: stubPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stubPath.path)

        let oldPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let oldClaudeCmd = ProcessInfo.processInfo.environment["CLAUDE_CMD"]
        let basePath = "/usr/bin:/bin:/usr/sbin:/sbin"
        let newPath = "\(stubDir.path):\(basePath)\(oldPath.isEmpty ? "" : ":\(oldPath)")"
        setenv("PATH", newPath, 1)
        setenv("CLAUDE_CMD", "claude", 1)
        defer {
            setenv("PATH", oldPath, 1)
            if let oldClaudeCmd {
                setenv("CLAUDE_CMD", oldClaudeCmd, 1)
            } else {
                unsetenv("CLAUDE_CMD")
            }
        }

        let scriptPath = projectRoot().appendingPathComponent("scripts/rename_branch_from_diff.sh").path
        let runner = LocalProcessRunner()
        let result = try runner.run(["/bin/bash", scriptPath, repoDir.path], currentDirectory: nil)
        XCTAssertEqual(result.exitCode, 0, "Script failed: \(result.stderr)")

        let branch = try runGit(["rev-parse", "--abbrev-ref", "HEAD"], in: repoDir)
        XCTAssertEqual(branch.trimmingCharacters(in: .whitespacesAndNewlines), "feature-from-diff")
    }

    func testRenameScriptUsesCommittedDiffWhenWorkingTreeClean() throws {
        let tempDir = try TemporaryDirectory()
        let repoDir = tempDir.url.appendingPathComponent("repo")
        let remoteDir = tempDir.url.appendingPathComponent("remote.git")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)

        try runGit(["init", "-b", "main"], in: repoDir)
        try "hello".write(to: repoDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "init"], in: repoDir)

        try runGit(["init", "--bare", remoteDir.path], in: tempDir.url)
        try runGit(["remote", "add", "origin", remoteDir.path], in: repoDir)
        try runGit(["push", "-u", "origin", "main"], in: repoDir)

        try runGit(["checkout", "-b", "oslo"], in: repoDir)
        try "new work".write(to: repoDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: repoDir)
        try runGit(["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "change"], in: repoDir)

        let stubDir = tempDir.url.appendingPathComponent("stub")
        try FileManager.default.createDirectory(at: stubDir, withIntermediateDirectories: true)
        let stubPath = stubDir.appendingPathComponent("claude")
        let stubScript = """
        #!/bin/bash
        set -euo pipefail
        input=$(cat)
        if [[ -z \\"$input\\" ]]; then
          echo "no"
          exit 0
        fi
        echo "commit-based-rename"
        """
        try stubScript.write(to: stubPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stubPath.path)

        let oldPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let oldClaudeCmd = ProcessInfo.processInfo.environment["CLAUDE_CMD"]
        let basePath = "/usr/bin:/bin:/usr/sbin:/sbin"
        let newPath = "\(stubDir.path):\(basePath)\(oldPath.isEmpty ? "" : ":\(oldPath)")"
        setenv("PATH", newPath, 1)
        setenv("CLAUDE_CMD", "claude", 1)
        defer {
            setenv("PATH", oldPath, 1)
            if let oldClaudeCmd {
                setenv("CLAUDE_CMD", oldClaudeCmd, 1)
            } else {
                unsetenv("CLAUDE_CMD")
            }
        }

        let scriptPath = projectRoot().appendingPathComponent("scripts/rename_branch_from_diff.sh").path
        let runner = LocalProcessRunner()
        let result = try runner.run(["/bin/bash", scriptPath, repoDir.path], currentDirectory: nil)
        XCTAssertEqual(result.exitCode, 0, "Script failed: \\(result.stderr)")

        let branch = try runGit(["rev-parse", "--abbrev-ref", "HEAD"], in: repoDir)
        XCTAssertEqual(branch.trimmingCharacters(in: .whitespacesAndNewlines), "commit-based-rename")
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @discardableResult
    private func runGit(_ args: [String], in directory: URL) throws -> String {
        let runner = LocalProcessRunner()
        let result = try runner.run(["/usr/bin/env", "git"] + args, currentDirectory: directory)
        if result.exitCode != 0 {
            throw NSError(domain: "BranchRenameScriptTests", code: 1, userInfo: ["stderr": result.stderr])
        }
        return result.stdout
    }
}
