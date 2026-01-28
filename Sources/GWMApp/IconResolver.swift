import AppKit

enum IconSource: Equatable {
    case appBundle(String)
    case file(String)
    case sfSymbol(String)
    case missing
}

struct IconPayload: Equatable {
    var image: NSImage?
    var source: IconSource
}

protocol AppIconProviding {
    func icon(forBundleId bundleId: String) -> NSImage?
}

protocol FileImageLoading {
    func loadImage(at path: String) -> NSImage?
}

protocol SymbolImageProviding {
    func symbolImage(name: String) -> NSImage?
}

struct DefaultAppIconProvider: AppIconProviding {
    func icon(forBundleId bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

struct DefaultFileImageLoader: FileImageLoading {
    func loadImage(at path: String) -> NSImage? {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue || path.lowercased().hasSuffix(".app") {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return NSImage(contentsOfFile: path)
    }
}

struct DefaultSymbolImageProvider: SymbolImageProviding {
    func symbolImage(name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }
}

struct IconResolver {
    let appProvider: AppIconProviding
    let fileLoader: FileImageLoading
    let symbolProvider: SymbolImageProviding

    init(
        appProvider: AppIconProviding = DefaultAppIconProvider(),
        fileLoader: FileImageLoading = DefaultFileImageLoader(),
        symbolProvider: SymbolImageProviding = DefaultSymbolImageProvider()
    ) {
        self.appProvider = appProvider
        self.fileLoader = fileLoader
        self.symbolProvider = symbolProvider
    }

    func resolve(_ spec: IconSpec?) -> IconPayload {
        guard let spec else { return IconPayload(image: nil, source: .missing) }
        switch spec.type {
        case .appBundle:
            if let bundleId = spec.bundleId {
                return IconPayload(image: appProvider.icon(forBundleId: bundleId), source: .appBundle(bundleId))
            }
        case .file:
            if let path = spec.path {
                return IconPayload(image: fileLoader.loadImage(at: path), source: .file(path))
            }
        case .sfSymbol:
            if let symbol = spec.symbol {
                return IconPayload(image: symbolProvider.symbolImage(name: symbol), source: .sfSymbol(symbol))
            }
        }
        return IconPayload(image: nil, source: .missing)
    }
}
