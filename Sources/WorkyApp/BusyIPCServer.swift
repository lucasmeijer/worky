import Foundation
import Dispatch
import Darwin

struct BusyIPCMessage: Decodable {
    let action: String
    let worktreePath: String
    let owner: String
    let ttlSeconds: Double?
}

struct BusyIPCResponse: Encodable {
    let ok: Bool
    let error: String?

    static func success() -> BusyIPCResponse {
        BusyIPCResponse(ok: true, error: nil)
    }

    static func failure(_ message: String) -> BusyIPCResponse {
        BusyIPCResponse(ok: false, error: message)
    }
}

final class BusyIPCServer: @unchecked Sendable {
    private let socketURL: URL
    private let store: BusyClaimStore
    private let queue = DispatchQueue(label: "worky.busy.ipc")
    private var listenSocket: Int32 = -1
    private var source: DispatchSourceRead?

    init(socketURL: URL, store: BusyClaimStore) {
        self.socketURL = socketURL
        self.store = store
    }

    func start() {
        let directory = socketURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: socketURL.path) {
            try? FileManager.default.removeItem(at: socketURL)
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            print("Worky busy IPC: failed to create socket")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketURL.path.utf8)
        let maxLength = MemoryLayout.size(ofValue: addr.sun_path) - 1
        if pathBytes.count > maxLength {
            close(fd)
            print("Worky busy IPC: socket path too long")
            return
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { buffer in
            buffer.copyBytes(from: pathBytes)
            buffer[ pathBytes.count ] = 0
        }

        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, length)
            }
        }
        guard bindResult == 0 else {
            close(fd)
            print("Worky busy IPC: bind failed")
            return
        }

        guard listen(fd, 16) == 0 else {
            close(fd)
            print("Worky busy IPC: listen failed")
            return
        }

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        listenSocket = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnections()
        }
        source.resume()
        self.source = source
    }

    func stop() {
        let fd = listenSocket
        listenSocket = -1
        source?.cancel()
        source = nil
        if fd >= 0 {
            close(fd)
        }
        if FileManager.default.fileExists(atPath: socketURL.path) {
            try? FileManager.default.removeItem(at: socketURL)
        }
    }

    private func acceptConnections() {
        while true {
            var addr = sockaddr()
            var length: socklen_t = socklen_t(MemoryLayout<sockaddr>.size)
            let client = accept(listenSocket, &addr, &length)
            if client < 0 {
                if errno == EWOULDBLOCK || errno == EAGAIN {
                    break
                }
                return
            }
            let flags = fcntl(client, F_GETFL, 0)
            _ = fcntl(client, F_SETFL, flags & ~O_NONBLOCK)
            queue.async { [weak self] in
                self?.handleClient(client)
            }
        }
    }

    private func handleClient(_ client: Int32) {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(client, &buffer, buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
                if data.contains(0x0A) {
                    break
                }
            } else {
                break
            }
        }

        Task { @MainActor in
            let response = self.process(data)
            self.send(response: response, to: client)
        }
    }

    @MainActor
    private func process(_ data: Data) -> BusyIPCResponse {
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure("Empty request")
        }
        do {
            let message = try JSONDecoder().decode(BusyIPCMessage.self, from: trimmed)
            return apply(message)
        } catch {
            return .failure("Invalid JSON")
        }
    }

    @MainActor
    private func apply(_ message: BusyIPCMessage) -> BusyIPCResponse {
        let owner = message.owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = message.worktreePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, !path.isEmpty else {
            return .failure("Missing owner or worktreePath")
        }
        switch message.action {
        case "claim":
            guard let ttl = message.ttlSeconds, ttl > 0 else {
                return .failure("Missing ttlSeconds")
            }
            store.claim(worktreePath: path, owner: owner, ttl: ttl)
            return .success()
        case "release":
            store.release(worktreePath: path, owner: owner)
            return .success()
        default:
            return .failure("Unknown action")
        }
    }

    private func send(response: BusyIPCResponse, to client: Int32) {
        let payload = (try? JSONEncoder().encode(response)) ?? Data()
        payload.withUnsafeBytes { bytes in
            _ = write(client, bytes.baseAddress, payload.count)
        }
        close(client)
    }
}

private extension Data {
    func trimmingCharacters(in set: CharacterSet) -> Data {
        guard let string = String(data: self, encoding: .utf8) else { return self }
        let trimmed = string.trimmingCharacters(in: set)
        return Data(trimmed.utf8)
    }
}
