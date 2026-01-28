import Foundation
import AppKit
import ApplicationServices

struct Options {
    var bundleId: String?
    var ownerName: String?
    var windowTitle: String?
    var buttonLabel: String
    var timeout: TimeInterval = 5
    var pollInterval: TimeInterval = 0.2
    var listButtons: Bool = false
}

func printUsage() {
    let text = """
    gwm-click
      --bundle-id <id>      App bundle id (optional)
      --owner-name <name>   Process name (optional)
      --label <label>       Button accessibility label/title (required)
      --window-title <t>    Window title match (optional)
      --timeout <sec>       Timeout seconds (default 5)
    """
    print(text)
}

func parseOptions() -> Options? {
    var args = CommandLine.arguments.dropFirst()
    var bundleId: String?
    var ownerName: String?
    var label: String?
    var windowTitle: String?
    var timeout: TimeInterval = 5
    var listButtons = false

    while let arg = args.first {
        args = args.dropFirst()
        switch arg {
        case "--bundle-id":
            bundleId = args.first
            args = args.dropFirst()
        case "--owner-name":
            ownerName = args.first
            args = args.dropFirst()
        case "--label":
            label = args.first
            args = args.dropFirst()
        case "--window-title":
            windowTitle = args.first
            args = args.dropFirst()
        case "--timeout":
            if let value = args.first, let t = TimeInterval(value) {
                timeout = t
            }
            args = args.dropFirst()
        case "--list-buttons":
            listButtons = true
        case "--help":
            return nil
        default:
            break
        }
    }

    if bundleId == nil && ownerName == nil { return nil }
    let finalLabel = label ?? ""
    return Options(bundleId: bundleId, ownerName: ownerName, windowTitle: windowTitle, buttonLabel: finalLabel, timeout: timeout, listButtons: listButtons)
}

func findApp(_ bundleId: String) -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
}

func findAppByName(_ name: String) -> NSRunningApplication? {
    NSWorkspace.shared.runningApplications.first { app in
        app.localizedName == name
    }
}

func windowMatches(_ window: AXUIElement, title: String?) -> Bool {
    guard let title else { return true }
    var value: CFTypeRef?
    if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value) == .success,
       let windowTitle = value as? String {
        return windowTitle == title
    }
    return false
}

func copyChildren(_ element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
       let children = value as? [AXUIElement] {
        return children
    }
    return []
}

func matchesButton(_ element: AXUIElement, label: String) -> Bool {
    var roleValue: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) != .success {
        return false
    }
    guard let role = roleValue as? String, role == kAXButtonRole as String else {
        return false
    }

    var titleValue: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success,
       let title = titleValue as? String,
       title == label {
        return true
    }

    var descValue: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descValue) == .success,
       let desc = descValue as? String,
       desc == label {
        return true
    }

    return false
}

func findButton(in element: AXUIElement, label: String) -> AXUIElement? {
    if matchesButton(element, label: label) {
        return element
    }
    for child in copyChildren(element) {
        if let found = findButton(in: child, label: label) {
            return found
        }
    }
    return nil
}

func collectButtons(in element: AXUIElement, results: inout [String]) {
    var roleValue: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success,
       let role = roleValue as? String, role == kAXButtonRole as String {
        var title: String?
        var titleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success {
            title = titleValue as? String
        }
        var descValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descValue) == .success,
           let desc = descValue as? String {
            results.append(desc)
        } else if let title {
            results.append(title)
        } else {
            results.append("<untitled>")
        }
    }
    for child in copyChildren(element) {
        collectButtons(in: child, results: &results)
    }
}

func clickButton(app: NSRunningApplication, options: Options) -> Bool {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    var windows: [AXUIElement] = []
    var value: CFTypeRef?
    if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
       let list = value as? [AXUIElement] {
        windows = list
    }
    if windows.isEmpty {
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
           let focusedValue = value {
            windows = [focusedValue as! AXUIElement]
        }
    }
    if windows.isEmpty {
        windows = copyChildren(appElement).filter { element in
            var roleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success,
               let role = roleValue as? String {
                return role == kAXWindowRole as String
            }
            return false
        }
    }
    guard !windows.isEmpty else { return false }

    for window in windows where windowMatches(window, title: options.windowTitle) {
        if options.listButtons {
            var labels: [String] = []
            collectButtons(in: window, results: &labels)
            labels.forEach { print($0) }
            return true
        }
        if let button = findButton(in: window, label: options.buttonLabel) {
            return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
        }
    }
    return false
}

if let options = parseOptions() {
    guard AXIsProcessTrusted() else {
        print("Accessibility permission not granted")
        exit(2)
    }

    let deadline = Date().addingTimeInterval(options.timeout)
    var success = false
    while Date() < deadline {
        let app: NSRunningApplication?
        if let bundleId = options.bundleId {
            app = findApp(bundleId)
        } else if let ownerName = options.ownerName {
            app = findAppByName(ownerName)
        } else {
            app = nil
        }
        if let app {
            success = clickButton(app: app, options: options)
            if success { break }
        }
        Thread.sleep(forTimeInterval: options.pollInterval)
    }

    if !success {
        print("Failed to click button")
        exit(1)
    }
} else {
    printUsage()
    exit(1)
}
