import Foundation
import AppKit

struct Options {
    var bundleId: String?
    var ownerName: String?
    var title: String?
    var outPath: String
    var timeout: TimeInterval = 5
    var pollInterval: TimeInterval = 0.2
}

func printUsage() {
    let text = """
    gwm-screenshot
      --bundle-id <id>      App bundle id to match (optional)
      --owner-name <name>   Process owner name (optional)
      --title <title>       Window title to match (optional)
      --out <path>          Output PNG path (required)
      --timeout <sec>       Timeout seconds (default 5)
    """
    print(text)
}

func parseOptions() -> Options? {
    var args = CommandLine.arguments.dropFirst()
    var bundleId: String?
    var ownerName: String?
    var title: String?
    var outPath: String?
    var timeout: TimeInterval = 5

    while let arg = args.first {
        args = args.dropFirst()
        switch arg {
        case "--bundle-id":
            bundleId = args.first
            args = args.dropFirst()
        case "--owner-name":
            ownerName = args.first
            args = args.dropFirst()
        case "--title":
            title = args.first
            args = args.dropFirst()
        case "--out":
            outPath = args.first
            args = args.dropFirst()
        case "--timeout":
            if let value = args.first, let t = TimeInterval(value) {
                timeout = t
            }
            args = args.dropFirst()
        case "--help":
            return nil
        default:
            break
        }
    }

    guard let outPath else { return nil }
    return Options(bundleId: bundleId, ownerName: ownerName, title: title, outPath: outPath, timeout: timeout)
}

func windowOwnerPid(bundleId: String) -> pid_t? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.processIdentifier
}

func findWindowId(options: Options) -> CGWindowID? {
    let windowListInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
    guard let windows = windowListInfo else { return nil }

    let ownerPid = options.bundleId.flatMap(windowOwnerPid)

    let filtered = windows.compactMap { window -> (CGWindowID, CGRect, String?)? in
        guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }
        guard let windowId = window[kCGWindowNumber as String] as? CGWindowID else { return nil }
        let ownerName = window[kCGWindowOwnerName as String] as? String
        let title = window[kCGWindowName as String] as? String
        let boundsDict = window[kCGWindowBounds as String] as? [String: Any]
        let bounds = CGRect(
            x: boundsDict?["X"] as? CGFloat ?? 0,
            y: boundsDict?["Y"] as? CGFloat ?? 0,
            width: boundsDict?["Width"] as? CGFloat ?? 0,
            height: boundsDict?["Height"] as? CGFloat ?? 0
        )

        if let pid = ownerPid {
            if let windowPid = window[kCGWindowOwnerPID as String] as? pid_t, windowPid != pid {
                return nil
            }
        } else if let ownerNameFilter = options.ownerName {
            if ownerName != ownerNameFilter {
                return nil
            }
        }

        if let titleFilter = options.title, title != titleFilter {
            return nil
        }

        return (windowId, bounds, title)
    }

    guard !filtered.isEmpty else { return nil }
    let sorted = filtered.sorted { lhs, rhs in
        let a = lhs.1.width * lhs.1.height
        let b = rhs.1.width * rhs.1.height
        return a > b
    }
    return sorted.first?.0
}

func captureWindow(windowId: CGWindowID, outPath: String) throws {
    guard let image = CGWindowListCreateImage(
        .null,
        .optionIncludingWindow,
        windowId,
        [.bestResolution]
    ) else {
        throw NSError(domain: "GWMScreenshot", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to capture window image"])
    }

    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "GWMScreenshot", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }
    let url = URL(fileURLWithPath: outPath)
    try data.write(to: url)
}

if let options = parseOptions() {
    let deadline = Date().addingTimeInterval(options.timeout)
    var windowId: CGWindowID?
    while Date() < deadline {
        windowId = findWindowId(options: options)
        if windowId != nil { break }
        Thread.sleep(forTimeInterval: options.pollInterval)
    }

    guard let foundId = windowId else {
        print("No matching window found")
        exit(1)
    }

    do {
        try captureWindow(windowId: foundId, outPath: options.outPath)
    } catch {
        print("Failed: \(error.localizedDescription)")
        exit(2)
    }
} else {
    printUsage()
    exit(1)
}
