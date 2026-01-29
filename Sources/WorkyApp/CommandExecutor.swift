import Foundation

protocol CommandExecuting {
    func execute(_ command: [String]) throws
}

struct CommandExecutor: CommandExecuting {
    let runner: ProcessRunning

    func execute(_ command: [String]) throws {
        guard !command.isEmpty else { return }
        let resolved: [String]
        if let first = command.first, first.hasPrefix("/") {
            resolved = command
        } else {
            resolved = ["/usr/bin/env"] + command
        }
        let result = try runner.run(resolved, currentDirectory: nil)
        guard result.exitCode == 0 else {
            throw CommandExecutionError.failed(result.stderr)
        }
    }
}

enum CommandExecutionError: Error {
    case failed(String)
}
