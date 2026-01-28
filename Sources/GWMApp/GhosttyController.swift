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
        let windowTitle = ghosttyWindowTitle(projectName: projectName, worktreeName: worktreeName)
        print("GWM Ghostty: looking for existing window with title \"\(windowTitle)\"")
        if focusExistingWindow(title: windowTitle) {
            print("GWM Ghostty: focused existing window")
            return
        }
        if openWithAppleScript(worktreePath: worktreePath, windowTitle: windowTitle) {
            return
        }
        let command = [
            Self.openExecutable,
            "-n",
            "-a",
            "Ghostty.app",
            "--args",
            "--working-directory=\(worktreePath)",
            "--title=\(windowTitle)"
        ]
        print("GWM Ghostty: launching new window")
        print("GWM Ghostty: command \(command.joined(separator: " "))")
        _ = try? runner.run(command, currentDirectory: nil)
    }

    private func openWithAppleScript(worktreePath: String, windowTitle: String) -> Bool {
        let openCommand = ghosttyOpenCommand(worktreePath: worktreePath, windowTitle: windowTitle)
        let script = [
            "tell application \"Ghostty\" to activate",
            "do shell script \"\(openCommand)\""
        ]
        var command = [Self.osascriptExecutable]
        for line in script {
            command.append("-e")
            command.append(line)
        }
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

    private func ghosttyOpenCommand(worktreePath: String, windowTitle: String) -> String {
        let args = [
            Self.openExecutable,
            "-n",
            "-a",
            "Ghostty.app",
            "--args",
            "--working-directory=\(worktreePath)",
            "--title=\(windowTitle)"
        ]
        return args.map(shellEscape).joined(separator: " ")
    }

    private func shellEscape(_ value: String) -> String {
        if value.isEmpty {
            return "''"
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
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
