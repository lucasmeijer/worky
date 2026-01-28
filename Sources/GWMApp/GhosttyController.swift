import AppKit
import ApplicationServices
import Foundation

protocol GhosttyControlling {
    func openOrFocus(projectName: String, worktreeName: String, worktreePath: String)
}

struct GhosttyController: GhosttyControlling {
    let runner: ProcessRunning

    private static let bundleId = "com.mitchellh.ghostty"
    private static let osascriptExecutable = "/usr/bin/osascript"
    private static let openExecutable = "/usr/bin/open"

    func openOrFocus(projectName: String, worktreeName: String, worktreePath: String) {
        // Convert worktree path to file:// URL with trailing slash (matching AXDocument format)
        let targetURL = URL(fileURLWithPath: worktreePath, isDirectory: true).absoluteString
        print("GWM Ghostty: looking for window with directory \"\(worktreePath)\"")
        print("GWM Ghostty: target URL: \(targetURL)")

        if focusExistingWindow(documentURL: targetURL) {
            print("GWM Ghostty: focused existing window")
            return
        }

        print("GWM Ghostty: no existing window found, creating new one")
        if openWithAppleScript(worktreePath: worktreePath) {
            return
        }

        let command = [
            Self.openExecutable,
            "-n",
            "-a",
            "Ghostty.app",
            "--args",
            "--working-directory=\(worktreePath)"
        ]
        print("GWM Ghostty: launching new window")
        print("GWM Ghostty: command \(command.joined(separator: " "))")
        _ = try? runner.run(command, currentDirectory: nil)
    }

    private func openWithAppleScript(worktreePath: String) -> Bool {
        let script = [
            "tell application \"Ghostty\"",
            "    activate",
            "    tell application \"System Events\"",
            "        keystroke \"n\" using {command down}",
            "    end tell",
            "    delay 0.5",
            "    tell application \"System Events\"",
            "        keystroke \"cd '\(worktreePath)' && clear\"",
            "        keystroke return",
            "    end tell",
            "end tell"
        ].joined(separator: "\n")

        let command = [Self.osascriptExecutable, "-e", script]
        print("GWM Ghostty: launching via AppleScript")
        let result = try? runner.run(command, currentDirectory: nil)
        if let result, result.exitCode == 0 {
            return true
        }
        if ProcessInfo.processInfo.environment["GWM_GHOSTTY_DEBUG"] == "1" {
            print("GWM Ghostty: AppleScript launch failed: \(result?.stderr ?? "unknown error")")
        }
        return false
    }

    private func focusExistingWindow(documentURL: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let debug = ProcessInfo.processInfo.environment["GWM_GHOSTTY_DEBUG"] == "1"
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleId)
        for app in apps {
            if focusWindow(in: app, documentURL: documentURL, debug: debug) {
                return true
            }
        }
        return false
    }

    private func focusWindow(in app: NSRunningApplication, documentURL: String, debug: Bool) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return false
        }

        for window in windows {
            // Get AXDocument attribute (working directory as file:// URL)
            var documentValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, "AXDocument" as CFString, &documentValue) == .success,
               let windowDocument = documentValue as? String {
                if debug {
                    var titleValue: CFTypeRef?
                    let windowTitle = if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
                                         let title = titleValue as? String {
                        title
                    } else {
                        "<unknown>"
                    }
                    print("GWM Ghostty AX window: title=\"\(windowTitle)\" document=\"\(windowDocument)\"")
                }
                if windowDocument == documentURL {
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                    app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                    return true
                }
            }
        }
        return false
    }
}
