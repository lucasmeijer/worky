import XCTest
@testable import GWMApp

final class ConfigPathsTests: XCTestCase {
    func testConfigDirRespectsOverride() {
        let previous = getenv("GWM_CONFIG_DIR")
        setenv("GWM_CONFIG_DIR", "/tmp/gwm-config-test", 1)
        defer {
            if let previous {
                setenv("GWM_CONFIG_DIR", previous, 1)
            } else {
                unsetenv("GWM_CONFIG_DIR")
            }
        }

        XCTAssertEqual(ConfigPaths.homeConfigDirectory.path, "/tmp/gwm-config-test")
    }

    func testWorktreeRootRespectsOverride() {
        let previous = getenv("GWM_WORKTREE_ROOT")
        setenv("GWM_WORKTREE_ROOT", "/tmp/gwm-root-test", 1)
        defer {
            if let previous {
                setenv("GWM_WORKTREE_ROOT", previous, 1)
            } else {
                unsetenv("GWM_WORKTREE_ROOT")
            }
        }

        XCTAssertEqual(ConfigPaths.worktreeRoot.path, "/tmp/gwm-root-test")
    }
}
