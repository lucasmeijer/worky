struct DefaultButtons {
    static let ghostty = ButtonDefinition(
        id: "ghostty",
        label: "Ghostty",
        icon: IconSpec(type: .sfSymbol, bundleId: nil, path: nil, symbol: "terminal.fill"),
        availability: AvailabilitySpec(bundleId: "com.mitchellh.ghostty", appName: nil),
        command: [
            "open",
            "-a",
            "Ghostty.app",
            "--args",
            "--working-directory=$WORKTREE",
            "window-width=420",
            "--window-height=40",
            "--title=GWM: $WORKTREE_NAME"
        ]
    )

    static let fork = ButtonDefinition(
        id: "fork",
        label: "Fork",
        icon: IconSpec(type: .sfSymbol, bundleId: nil, path: nil, symbol: "arrow.triangle.branch"),
        availability: AvailabilitySpec(bundleId: "com.DanPristupov.Fork", appName: nil),
        command: ["open", "-a", "Fork", "$WORKTREE"]
    )

    static let all: [ButtonDefinition] = [ghostty, fork]
}
