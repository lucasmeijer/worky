import XCTest
@testable import GWMApp
import AppKit

final class IconResolverTests: XCTestCase {
    func testResolvesAppBundleIcon() {
        let resolver = IconResolver(
            appProvider: FakeAppProvider(),
            fileLoader: FakeFileLoader(),
            symbolProvider: FakeSymbolProvider()
        )
        let payload = resolver.resolve(IconSpec(type: .appBundle, bundleId: "com.example", path: nil, symbol: nil))
        XCTAssertEqual(payload.source, .appBundle("com.example"))
    }

    func testResolvesFileIcon() {
        let resolver = IconResolver(
            appProvider: FakeAppProvider(),
            fileLoader: FakeFileLoader(),
            symbolProvider: FakeSymbolProvider()
        )
        let payload = resolver.resolve(IconSpec(type: .file, bundleId: nil, path: "/tmp/icon.png", symbol: nil))
        XCTAssertEqual(payload.source, .file("/tmp/icon.png"))
    }

    func testResolvesSymbolIcon() {
        let resolver = IconResolver(
            appProvider: FakeAppProvider(),
            fileLoader: FakeFileLoader(),
            symbolProvider: FakeSymbolProvider()
        )
        let payload = resolver.resolve(IconSpec(type: .sfSymbol, bundleId: nil, path: nil, symbol: "star.fill"))
        XCTAssertEqual(payload.source, .sfSymbol("star.fill"))
    }
}

private struct FakeAppProvider: AppIconProviding {
    func icon(forBundleId bundleId: String) -> NSImage? { NSImage() }
}

private struct FakeFileLoader: FileImageLoading {
    func loadImage(at path: String) -> NSImage? { NSImage() }
}

private struct FakeSymbolProvider: SymbolImageProviding {
    func symbolImage(name: String) -> NSImage? { NSImage() }
}
