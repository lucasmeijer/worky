import XCTest
@testable import GWMApp

final class GitWorktreeParserTests: XCTestCase {
    func testParsesPorcelainOutput() throws {
        let output = """
        worktree /tmp/repo/main
        HEAD 1234567890abcdef
        branch refs/heads/main
        
        worktree /tmp/repo/feature
        HEAD fedcba0987654321
        branch refs/heads/feature
        
        """

        let entries = GitWorktreeParser.parsePorcelain(output)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].path, "/tmp/repo/main")
        XCTAssertEqual(entries[0].head, "1234567890abcdef")
        XCTAssertEqual(entries[0].branch, "refs/heads/main")
        XCTAssertEqual(entries[1].path, "/tmp/repo/feature")
        XCTAssertEqual(entries[1].branch, "refs/heads/feature")
    }

    func testParsesDetachedHead() throws {
        let output = """
        worktree /tmp/repo/detached
        HEAD 1111111111111111
        detached

        """

        let entries = GitWorktreeParser.parsePorcelain(output)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].path, "/tmp/repo/detached")
        XCTAssertEqual(entries[0].head, "1111111111111111")
        XCTAssertNil(entries[0].branch)
    }

    func testParsesPrunableWorktree() throws {
        let output = """
        worktree /tmp/repo/removed
        HEAD 2222222222222222
        branch refs/heads/feature
        prunable gitdir file points to non-existent location

        """

        let entries = GitWorktreeParser.parsePorcelain(output)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].path, "/tmp/repo/removed")
        XCTAssertEqual(entries[0].head, "2222222222222222")
        XCTAssertEqual(entries[0].branch, "refs/heads/feature")
        XCTAssertTrue(entries[0].isPrunable)
    }

    func testMixedNormalAndPrunableWorktrees() throws {
        let output = """
        worktree /tmp/repo/main
        HEAD 1234567890abcdef
        branch refs/heads/main

        worktree /tmp/repo/removed
        HEAD 2222222222222222
        branch refs/heads/old-feature
        prunable gitdir file points to non-existent location

        worktree /tmp/repo/feature
        HEAD fedcba0987654321
        branch refs/heads/feature

        """

        let entries = GitWorktreeParser.parsePorcelain(output)

        XCTAssertEqual(entries.count, 3)
        XCTAssertFalse(entries[0].isPrunable)
        XCTAssertTrue(entries[1].isPrunable)
        XCTAssertFalse(entries[2].isPrunable)
    }
}
