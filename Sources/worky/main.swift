import Foundation
import Network

struct BusyIPCMessage: Codable {
    let action: String
    let worktreePath: String
    let owner: String
    let ttlSeconds: Double?
}

struct BusyIPCResponse: Decodable {
    let ok: Bool
    let error: String?
}

enum IPCError: Error {
    case message(String)
}

final class IPCResultBox: @unchecked Sendable {
    var response: BusyIPCResponse?
    var errorMessage: String?
}

func printUsage() {
    let text = """
    worky
      claimbusy <owner> <timeout>
      ready <owner>

    examples:
      worky claimbusy claudecode 5m
      worky ready claudecode
    """
    print(text)
}

func parseDuration(_ value: String) -> TimeInterval? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let unit = trimmed.last
    let multiplier: Double
    let numberString: String
    if unit == "s" || unit == "m" || unit == "h" {
        multiplier = (unit == "h") ? 3600 : (unit == "m") ? 60 : 1
        numberString = String(trimmed.dropLast())
    } else {
        multiplier = 1
        numberString = trimmed
    }
    guard let number = Double(numberString) else { return nil }
    return number * multiplier
}

func runGitShowTopLevel() -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git", "-C", FileManager.default.currentDirectoryPath, "rev-parse", "--show-toplevel"]
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return nil
    }
    guard process.terminationStatus == 0 else { return nil }
    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return nil }
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return URL(fileURLWithPath: trimmed).resolvingSymlinksInPath().path
}

func socketURL() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".worky")
        .appendingPathComponent("run")
        .appendingPathComponent("worky.sock")
}

func sendMessage(_ message: BusyIPCMessage) -> Result<BusyIPCResponse, IPCError> {
    let endpoint = NWEndpoint.unix(path: socketURL().path)
    let params = NWParameters.tcp
    let connection = NWConnection(to: endpoint, using: params)
    let queue = DispatchQueue(label: "worky.cli.ipc")
    let semaphore = DispatchSemaphore(value: 0)

    let box = IPCResultBox()

    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            var payload = (try? JSONEncoder().encode(message)) ?? Data()
            payload.append(0x0A)
            connection.send(content: payload, completion: .contentProcessed { error in
                if let error {
                    box.errorMessage = error.localizedDescription
                    semaphore.signal()
                    return
                }
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                    if let data, let decoded = try? JSONDecoder().decode(BusyIPCResponse.self, from: data) {
                        box.response = decoded
                    } else if data != nil {
                        box.errorMessage = "Invalid response"
                    }
                    semaphore.signal()
                }
            })
        case .failed(let error):
            box.errorMessage = error.localizedDescription
            semaphore.signal()
        default:
            break
        }
    }

    connection.start(queue: queue)
    let timeout = semaphore.wait(timeout: .now() + 3)
    connection.cancel()

    if timeout == .timedOut {
        return .failure(.message("Timed out waiting for Worky"))
    }
    if let errorMessage = box.errorMessage {
        return .failure(.message(errorMessage))
    }
    if let response = box.response {
        return .success(response)
    }
    return .failure(.message("No response from Worky"))
}

let args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty {
    printUsage()
    exit(1)
}

let command = args[0]
let owner: String
let ttlSeconds: TimeInterval?

switch command {
case "claimbusy":
    guard args.count >= 3 else {
        printUsage()
        exit(1)
    }
    owner = args[1]
    guard let duration = parseDuration(args[2]) else {
        print("Invalid timeout: \(args[2])")
        exit(1)
    }
    ttlSeconds = duration
case "ready":
    guard args.count >= 2 else {
        printUsage()
        exit(1)
    }
    owner = args[1]
    ttlSeconds = nil
default:
    printUsage()
    exit(1)
}

guard let worktreePath = runGitShowTopLevel() else {
    print("Not in a git worktree")
    exit(1)
}

let message = BusyIPCMessage(
    action: command == "claimbusy" ? "claim" : "release",
    worktreePath: worktreePath,
    owner: owner,
    ttlSeconds: ttlSeconds
)

switch sendMessage(message) {
case .success(let response):
    if response.ok {
        exit(0)
    } else {
        print(response.error ?? "Worky rejected the request")
        exit(1)
    }
case .failure(let error):
    if case let .message(message) = error {
        print(message)
    }
    exit(1)
}
