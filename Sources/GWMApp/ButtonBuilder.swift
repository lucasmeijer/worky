import Foundation
import AppKit

struct ButtonDefinition: Equatable {
    var id: String
    var label: String
    var icon: IconSpec?
    var availability: AvailabilitySpec?
    var command: [String]
}

struct ResolvedButton: Equatable {
    var id: String
    var label: String
    var icon: IconSpec?
    var command: [String]
    var isEnabled: Bool
}

protocol AppAvailabilityChecking {
    func isAvailable(_ spec: AvailabilitySpec?) -> Bool
}

struct AppAvailabilityChecker: AppAvailabilityChecking {
    func isAvailable(_ spec: AvailabilitySpec?) -> Bool {
        guard let spec else { return true }
        if let bundleId = spec.bundleId as String? {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil {
                return true
            }
        }
        return false
    }
}

struct ButtonBuilder {
    let availability: AppAvailabilityChecking
    let templateEngine: TemplateEngine

    init(availability: AppAvailabilityChecking, templateEngine: TemplateEngine = TemplateEngine()) {
        self.availability = availability
        self.templateEngine = templateEngine
    }

    func build(defaults: [ButtonDefinition], configButtons: [ButtonConfig], variables: [String: String]) -> [ResolvedButton] {
        let configDefinitions = configButtons.map { config -> ButtonDefinition in
            let id = config.id ?? slugify(config.label)
            return ButtonDefinition(
                id: id,
                label: config.label,
                icon: config.icon,
                availability: config.availability,
                command: config.command
            )
        }
        let all = defaults + configDefinitions
        return all.map { def in
            ResolvedButton(
                id: def.id,
                label: def.label,
                icon: def.icon,
                command: templateEngine.apply(def.command, variables: variables),
                isEnabled: availability.isAvailable(def.availability)
            )
        }
    }

    private func slugify(_ value: String) -> String {
        let lower = value.lowercased()
        let allowed = lower.map { char -> Character in
            if char.isLetter || char.isNumber { return char }
            return "-"
        }
        return String(allowed).replacingOccurrences(of: "--", with: "-")
    }
}
