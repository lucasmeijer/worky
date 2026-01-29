import Foundation

struct BuiltinAppDefinition {
    let id: String
    let label: String
    let appPath: String
    let icon: IconSpec
    let command: [String]
}

struct BuiltinApps {
    static let all: [BuiltinAppDefinition] = [
        BuiltinAppDefinition(
            id: "ghostty",
            label: "Ghostty",
            appPath: "/Applications/Ghostty.app",
            icon: IconSpec(type: .file, bundleId: nil, path: "/Applications/Ghostty.app", symbol: nil),
            command: [
                "open",
                "-a",
                "Ghostty.app",
                "--args",
                "--working-directory=$WORKTREE",
                "window-width=420",
                "--window-height=40",
                "--title=Worky: $WORKTREE_NAME"
            ]
        ),
        BuiltinAppDefinition(
            id: "fork",
            label: "Fork",
            appPath: "/Applications/Fork.app",
            icon: IconSpec(type: .file, bundleId: nil, path: "/Applications/Fork.app", symbol: nil),
            command: ["open", "-a", "Fork", "$WORKTREE"]
        ),
        BuiltinAppDefinition(
            id: "vscode",
            label: "VS Code",
            appPath: "/Applications/Visual Studio Code.app",
            icon: IconSpec(type: .file, bundleId: nil, path: "/Applications/Visual Studio Code.app", symbol: nil),
            command: ["open", "-a", "Visual Studio Code", "$WORKTREE"]
        )
    ]

    static func detectInstalled(excluding: Set<String> = []) -> [AppConfig] {
        return all
            .filter { !excluding.contains($0.id) }
            .filter { FileManager.default.fileExists(atPath: $0.appPath) }
            .map { builtin in
                AppConfig(
                    id: builtin.id,
                    label: builtin.label,
                    icon: builtin.icon,
                    command: builtin.command
                )
            }
    }
}
