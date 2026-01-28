import AppKit
import ApplicationServices

protocol GhosttyControlling {
    func openOrFocus(worktreePath: String, title: String)
}

struct GhosttyController: GhosttyControlling {
    let runner: ProcessRunning

    func openOrFocus(worktreePath: String, title: String) {
        if focusExistingWindow(title: title) {
            return
        }
        _ = try? runner.run([
            "/usr/bin/env",
            "open",
            "-a",
            "Ghostty.app",
            "--args",
            "--working-directory=\(worktreePath)",
            "window-width=420",
            "--window-height=40",
            "--title=GWM: \(title)"
        ], currentDirectory: nil)
    }

    private func focusExistingWindow(title: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.mitchellh.ghostty").first else {
            return false
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return false
        }

        for window in windows {
            var titleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
               let windowTitle = titleValue as? String,
               windowTitle == "GWM: \(title)" {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return true
            }
        }
        return false
    }
}
