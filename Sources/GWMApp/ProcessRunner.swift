import Foundation

struct ProcessResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

protocol ProcessRunning: Sendable {
    func run(_ command: [String], currentDirectory: URL?) throws -> ProcessResult
}

struct LocalProcessRunner: ProcessRunning, Sendable {
    func run(_ command: [String], currentDirectory: URL?) throws -> ProcessResult {
        guard let executable = command.first else {
            throw ProcessRunnerError.emptyCommand
        }
        let args = Array(command.dropFirst())

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return ProcessResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }
}

enum ProcessRunnerError: Error {
    case emptyCommand
}
