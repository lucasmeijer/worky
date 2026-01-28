import XCTest
@testable import GWMApp

@MainActor
final class BusyClaimStoreTests: XCTestCase {
    func testClaimAndRelease() {
        let now = Date(timeIntervalSince1970: 100)
        let store = BusyClaimStore(clock: { now }, autoTick: false)

        store.claim(worktreePath: "/tmp/worktree", owner: "claude", ttl: 30)
        let snapshotAfterClaim = store.snapshot()
        XCTAssertEqual(snapshotAfterClaim["/tmp/worktree"]?.count, 1)

        store.release(worktreePath: "/tmp/worktree", owner: "claude")
        let snapshotAfterRelease = store.snapshot()
        XCTAssertNil(snapshotAfterRelease["/tmp/worktree"])
    }

    func testClaimsExpireOnTick() {
        var now = Date(timeIntervalSince1970: 100)
        let store = BusyClaimStore(clock: { now }, autoTick: false)

        store.claim(worktreePath: "/tmp/worktree", owner: "claude", ttl: 5)
        now = now.addingTimeInterval(6)
        store.tick()

        XCTAssertNil(store.snapshot()["/tmp/worktree"])
    }
}
