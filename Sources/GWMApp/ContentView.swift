import SwiftUI
import AppKit

struct ContentView: View {
    @State private var appear = false
    private let projects = SampleData.projects

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                    ProjectSection(project: project)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.08), value: appear)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(background)
        .overlay(
            WindowAccessor { window in
                window.isMovableByWindowBackground = true
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.backgroundColor = .clear
            }
        )
        .frame(minHeight: 420)
        .onAppear { appear = true }
    }


    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.ink.opacity(0.95),
                    Theme.ocean.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RoundedRectangle(cornerRadius: 320, style: .continuous)
                .fill(Theme.coral.opacity(0.28))
                .frame(width: 560, height: 320)
                .rotationEffect(.degrees(-12))
                .offset(x: 260, y: -140)
            Circle()
                .fill(Theme.seafoam.opacity(0.30))
                .frame(width: 260, height: 260)
                .offset(x: -220, y: -140)
        }
        .ignoresSafeArea()
    }

    private var preferencesButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape.fill")
            Text("Preferences")
                .font(.custom("Avenir Next", size: 12))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.ink.opacity(0.85), in: Capsule())
        .foregroundStyle(Theme.sand)
    }
}

struct ProjectSection: View {
    let project: Project

    var body: some View {
        VStack(spacing: 12) {
            header
            VStack(spacing: 12) {
                ForEach(project.worktrees) { worktree in
                    WorktreeRow(worktree: worktree)
                }
            }
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.ink.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.name)
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.ink)
            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("New Worktree")
                        .font(.custom("Avenir Next", size: 12))
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.ocean)
        }
    }
}

struct WorktreeRow: View {
    let worktree: Worktree

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                titleBlock
                IconGrid(buttons: worktree.buttons)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                trashButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
        )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(worktree.name)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.ink)
            Text(worktree.lastActivity)
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(Theme.ink.opacity(0.55))
        }
    }

    private var trashButton: some View {
        Button(action: {}) {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.bordered)
        .tint(Theme.coral)
    }
}

struct IconGrid: View {
    let buttons: [AppButton]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 26), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(buttons) { button in
                AppIconButton(button: button)
            }
        }
    }
}

struct AppIconButton: View {
    let button: AppButton

    var body: some View {
        Button(action: {}) {
            Image(systemName: button.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.bordered)
        .tint(button.enabled ? button.tint : .gray)
        .disabled(!button.enabled)
        .help(button.enabled ? button.title : "\(button.title) (not installed)")
    }
}

enum Theme {
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let sand = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let card = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let ocean = Color(red: 0.08, green: 0.50, blue: 0.46)
    static let coral = Color(red: 0.90, green: 0.36, blue: 0.30)
    static let seafoam = Color(red: 0.62, green: 0.86, blue: 0.78)
}

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onWindow(window)
            }
        }
    }
}

enum SampleData {
    static let projects: [Project] = [
        Project(
            name: "Curiosity1",
            basePath: "~/gwm/Curiosity1",
            worktrees: [
                Worktree(
                    name: "sydney",
                    path: "~/gwm/Curiosity1/sydney",
                    lastActivity: "5 min ago",
                    buttons: [
                        AppButton(title: "Ghostty", systemImage: "terminal.fill", enabled: true, tint: Color(red: 0.18, green: 0.68, blue: 0.64)),
                        AppButton(title: "Fork", systemImage: "arrow.triangle.branch", enabled: true, tint: Color(red: 0.94, green: 0.55, blue: 0.18)),
                        AppButton(title: "Rider", systemImage: "cube.fill", enabled: false, tint: Color(red: 0.26, green: 0.42, blue: 0.9))
                    ]
                ),
                Worktree(
                    name: "oslo",
                    path: "~/gwm/Curiosity1/oslo",
                    lastActivity: "1 hr ago",
                    buttons: [
                        AppButton(title: "Ghostty", systemImage: "terminal.fill", enabled: true, tint: Color(red: 0.18, green: 0.68, blue: 0.64)),
                        AppButton(title: "Fork", systemImage: "arrow.triangle.branch", enabled: true, tint: Color(red: 0.94, green: 0.55, blue: 0.18)),
                        AppButton(title: "Rider", systemImage: "cube.fill", enabled: true, tint: Color(red: 0.26, green: 0.42, blue: 0.9))
                    ]
                ),
                Worktree(
                    name: "kyoto",
                    path: "~/gwm/Curiosity1/kyoto",
                    lastActivity: "Yesterday",
                    buttons: [
                        AppButton(title: "Ghostty", systemImage: "terminal.fill", enabled: true, tint: Color(red: 0.18, green: 0.68, blue: 0.64)),
                        AppButton(title: "Fork", systemImage: "arrow.triangle.branch", enabled: false, tint: Color(red: 0.94, green: 0.55, blue: 0.18)),
                        AppButton(title: "Rider", systemImage: "cube.fill", enabled: false, tint: Color(red: 0.26, green: 0.42, blue: 0.9))
                    ]
                )
            ]
        ),
        Project(
            name: "life",
            basePath: "~/gwm/life",
            worktrees: [
                Worktree(
                    name: "helsinki",
                    path: "~/gwm/life/helsinki",
                    lastActivity: "3 days ago",
                    buttons: [
                        AppButton(title: "Ghostty", systemImage: "terminal.fill", enabled: true, tint: Color(red: 0.18, green: 0.68, blue: 0.64)),
                        AppButton(title: "Fork", systemImage: "arrow.triangle.branch", enabled: true, tint: Color(red: 0.94, green: 0.55, blue: 0.18))
                    ]
                ),
                Worktree(
                    name: "porto",
                    path: "~/gwm/life/porto",
                    lastActivity: "Jan 12",
                    buttons: [
                        AppButton(title: "Ghostty", systemImage: "terminal.fill", enabled: false, tint: Color(red: 0.18, green: 0.68, blue: 0.64)),
                        AppButton(title: "Fork", systemImage: "arrow.triangle.branch", enabled: true, tint: Color(red: 0.94, green: 0.55, blue: 0.18))
                    ]
                )
            ]
        )
    ]
}
