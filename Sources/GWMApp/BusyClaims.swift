import Foundation

struct BusyClaim: Identifiable, Equatable {
    let owner: String
    let expiresAt: Date

    var id: String { owner }

    func isExpired(now: Date) -> Bool {
        expiresAt <= now
    }
}

@MainActor
final class BusyClaimStore {
    private(set) var claimsByWorktree: [String: [BusyClaim]] = [:]
    var onUpdate: (([String: [BusyClaim]]) -> Void)?

    private let clock: () -> Date
    private var timer: Timer?

    init(clock: @escaping () -> Date = Date.init, autoTick: Bool = true) {
        self.clock = clock
        if autoTick {
            startTimer()
        }
    }

    func claim(worktreePath: String, owner: String, ttl: TimeInterval) {
        guard ttl > 0 else { return }
        let normalized = normalizePath(worktreePath)
        let expiresAt = clock().addingTimeInterval(ttl)
        var next = claimsByWorktree
        var claims = next[normalized] ?? []
        claims.removeAll { $0.owner == owner }
        claims.append(BusyClaim(owner: owner, expiresAt: expiresAt))
        claims.sort { $0.owner.localizedCaseInsensitiveCompare($1.owner) == .orderedAscending }
        next[normalized] = claims
        apply(next)
    }

    func release(worktreePath: String, owner: String) {
        let normalized = normalizePath(worktreePath)
        var next = claimsByWorktree
        guard var claims = next[normalized] else { return }
        claims.removeAll { $0.owner == owner }
        if claims.isEmpty {
            next.removeValue(forKey: normalized)
        } else {
            next[normalized] = claims
        }
        apply(next)
    }

    func tick() {
        pruneExpired(now: clock())
    }

    func snapshot() -> [String: [BusyClaim]] {
        claimsByWorktree
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.pruneExpired(now: self.clock())
            }
        }
    }

    private func pruneExpired(now: Date) {
        var next = claimsByWorktree
        var changed = false
        for (path, claims) in claimsByWorktree {
            let filtered = claims.filter { !$0.isExpired(now: now) }
            if filtered.count != claims.count {
                changed = true
                if filtered.isEmpty {
                    next.removeValue(forKey: path)
                } else {
                    next[path] = filtered
                }
            }
        }
        if changed {
            apply(next)
        }
    }

    private func apply(_ next: [String: [BusyClaim]]) {
        guard next != claimsByWorktree else { return }
        claimsByWorktree = next
        onUpdate?(next)
    }

    private func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }
}
