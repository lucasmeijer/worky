import XCTest
@testable import WorkyApp

final class CommandExecutorTests: XCTestCase {
    func testExecutesCommand() throws {
        let executor = CommandExecutor(runner: FakeRunner(result: ProcessResult(stdout: "ok", stderr: "", exitCode: 0)))
        XCTAssertNoThrow(try executor.execute(["echo", "hi"]))
    }

    func testThrowsOnFailure() {
        let executor = CommandExecutor(runner: FakeRunner(result: ProcessResult(stdout: "", stderr: "fail", exitCode: 1)))
        XCTAssertThrowsError(try executor.execute(["bad"]))
    }
}

private struct FakeRunner: ProcessRunning {
    let result: ProcessResult
    func run(_ command: [String], currentDirectory: URL?) throws -> ProcessResult { result }
}
