import Foundation

struct ResolvedButton: Equatable {
    var id: String
    var label: String
    var icon: IconSpec?
    var command: [String]
}

struct ButtonBuilder {
    let templateEngine: TemplateEngine

    init(templateEngine: TemplateEngine = TemplateEngine()) {
        self.templateEngine = templateEngine
    }

    func build(apps: [AppConfig], variables: [String: String]) -> [ResolvedButton] {
        return apps.map { app in
            let id = app.id ?? slugify(app.label)
            return ResolvedButton(
                id: id,
                label: app.label,
                icon: app.icon,
                command: templateEngine.apply(app.command, variables: variables)
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
