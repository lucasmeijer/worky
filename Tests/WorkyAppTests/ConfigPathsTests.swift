import XCTest
@testable import WorkyApp

final class ConfigPathsTests: XCTestCase {
    func testConfigDirRespectsOverride() {
        let previous = getenv("WORKY_CONFIG_DIR")
        setenv("WORKY_CONFIG_DIR", "/tmp/worky-config-test", 1)
        defer {
            if let previous {
                setenv("WORKY_CONFIG_DIR", previous, 1)
            } else {
                unsetenv("WORKY_CONFIG_DIR")
            }
        }

        XCTAssertEqual(ConfigPaths.homeConfigDirectory.path, "/tmp/worky-config-test")
    }

    func testWorktreeRootRespectsOverride() {
        let previous = getenv("WORKY_WORKTREE_ROOT")
        setenv("WORKY_WORKTREE_ROOT", "/tmp/worky-root-test", 1)
        defer {
            if let previous {
                setenv("WORKY_WORKTREE_ROOT", previous, 1)
            } else {
                unsetenv("WORKY_WORKTREE_ROOT")
            }
        }

        XCTAssertEqual(ConfigPaths.worktreeRoot.path, "/tmp/worky-root-test")
    }
}
