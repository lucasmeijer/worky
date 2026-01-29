import XCTest
@testable import WorkyApp

final class TemplateEngineTests: XCTestCase {
    func testReplacesKnownVariables() {
        let engine = TemplateEngine()
        let vars = [
            "WORKTREE": "/tmp/worktree",
            "WORKTREE_NAME": "oslo",
            "PROJECT_NAME": "Curiosity1",
            "REPO": "/tmp/repo.git"
        ]
        let input = [
            "open",
            "-a",
            "Ghostty.app",
            "--working-directory=$WORKTREE",
            "--title=Worky: $PROJECT_NAME / $WORKTREE_NAME",
            "--repo=$REPO",
            "--project=$PROJECT_NAME"
        ]
        let output = engine.apply(input, variables: vars)
        XCTAssertEqual(output, [
            "open",
            "-a",
            "Ghostty.app",
            "--working-directory=/tmp/worktree",
            "--title=Worky: Curiosity1 / oslo",
            "--repo=/tmp/repo.git",
            "--project=Curiosity1"
        ])
    }

    func testLeavesUnknownVariablesUntouched() {
        let engine = TemplateEngine()
        let output = engine.apply(["echo", "$UNKNOWN"], variables: [:])
        XCTAssertEqual(output, ["echo", "$UNKNOWN"])
    }
}
