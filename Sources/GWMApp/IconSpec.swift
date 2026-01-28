import Foundation

struct IconSpec: Codable, Equatable {
    var type: IconType
    var bundleId: String?
    var path: String?
    var symbol: String?
}

enum IconType: String, Codable {
    case appBundle
    case file
    case sfSymbol
}
