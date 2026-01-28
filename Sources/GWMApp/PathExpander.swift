import Foundation

enum PathExpander {
    static func expand(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == "~" { return home }
        if path.hasPrefix("~/") {
            return home + String(path.dropFirst(1))
        }
        return path
    }
}
