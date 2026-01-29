import SwiftUI

struct Project: Identifiable {
    let id = UUID()
    let name: String
    let basePath: String
    let worktrees: [Worktree]
}

struct Worktree: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let lastActivity: String
    let buttons: [AppButton]
}

struct AppButton: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let enabled: Bool
    let tint: Color
}
