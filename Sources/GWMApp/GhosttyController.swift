import AppKit
import ApplicationServices

protocol GhosttyControlling {
    func openOrFocus(projectName: String, worktreeName: String, worktreePath: String)
}

struct GhosttyController: GhosttyControlling {
    let runner: ProcessRunning

    private static let bundleId = "com.mitchellh.ghostty"
    func openOrFocus(projectName: String, worktreeName: String, worktreePath: String) {
        let windowTitle = ghosttyWindowTitle(projectName: projectName, worktreeName: worktreeName)
        if focusExistingWindow(title: windowTitle) {
            return
        }
        _ = try? runner.run([
            "/usr/bin/env",
            "open",
            "-a",
            "Ghostty.app",
            "--args",
            "--working-directory=\(worktreePath)",
            "--title=\(windowTitle)"
        ], currentDirectory: nil)
    }

    private func focusExistingWindow(title: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let debug = ProcessInfo.processInfo.environment["GWM_GHOSTTY_DEBUG"] == "1"
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleId)
        for app in apps {
            if focusWindow(in: app, title: title, debug: debug) {
                return true
            }
        }
        return false
    }

    private func focusWindow(in app: NSRunningApplication, title: String, debug: Bool) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return false
        }

        for window in windows {
            var titleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
               let windowTitle = titleValue as? String {
                if debug {
                    print("GWM Ghostty AX window title: \(windowTitle)")
                }
                if windowTitle == title || windowTitle.contains(title) {
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                    app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                    return true
                }
            }
        }
        return false
    }

    private func ghosttyWindowTitle(projectName: String, worktreeName: String) -> String {
        "Worky: \(projectName) / \(worktreeName)"
    }
}
