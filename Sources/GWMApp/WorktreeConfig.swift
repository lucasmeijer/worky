import Foundation

struct WorktreeConfig: Codable, Equatable {
    var buttons: [ButtonConfig]

    init(buttons: [ButtonConfig] = []) {
        self.buttons = buttons
    }
}

struct ButtonConfig: Codable, Equatable {
    var id: String?
    var label: String
    var icon: IconSpec?
    var availability: AvailabilitySpec?
    var command: [String]
}

struct AvailabilitySpec: Codable, Equatable {
    var bundleId: String
    var appName: String?
}

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
