import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel: ProjectsViewModel
    @State private var appear = false

    init(viewModel: ProjectsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Theme.coral)
                }
                ForEach(Array(viewModel.projects.enumerated()), id: \.element.id) { index, project in
                    ProjectSection(
                        project: project,
                        onAddWorktree: { viewModel.createWorktree(for: project) },
                        onRemoveWorktree: { worktree in viewModel.removeWorktree(worktree, from: project) },
                        onRunButton: { button, worktree in
                            viewModel.runButton(button, worktree: worktree, project: project)
                        }
                    )
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
        .background(ScrollViewConfigurator().allowsHitTesting(false))
        .background(background)
        .overlay(
            WindowAccessor { window in
                window.isMovableByWindowBackground = true
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.backgroundColor = .clear
            }
            .allowsHitTesting(false)
        )
        .frame(minHeight: 420)
        .onAppear {
            appear = true
            viewModel.load()
            if ProcessInfo.processInfo.environment["GWM_AUTO_QUIT"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private var header: some View {
        Text("Worky")
            .font(.custom("Avenir Next", size: 18))
            .fontWeight(.semibold)
            .foregroundStyle(Theme.sand)
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
}

struct ProjectSection: View {
    let project: ProjectViewData
    let onAddWorktree: () -> Void
    let onRemoveWorktree: (WorktreeViewData) -> Void
    let onRunButton: (ButtonViewData, WorktreeViewData) -> Void
    @State private var deleteTarget: WorktreeViewData?

    var body: some View {
        VStack(spacing: 12) {
            header
            VStack(spacing: 12) {
                ForEach(project.worktrees) { worktree in
                    WorktreeRow(
                        worktree: worktree,
                        onRemove: { deleteTarget = worktree },
                        onRunButton: { button in onRunButton(button, worktree) }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: project.worktrees.map(\.id))
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.ink.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
        .alert("Delete worktree?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let worktree = deleteTarget {
                    onRemoveWorktree(worktree)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            Text("This will remove the selected worktree.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.name)
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.ink)
            Button(action: onAddWorktree) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("New Worktree")
                        .font(.custom("Avenir Next", size: 12))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Theme.sand)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.ocean, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Worktree")
        }
    }
}

struct WorktreeRow: View {
    let worktree: WorktreeViewData
    let onRemove: () -> Void
    let onRunButton: (ButtonViewData) -> Void

    var body: some View {
        HStack() {
            titleBlock
            IconGrid(buttons: worktree.buttons, onRunButton: onRunButton)
                .frame(maxWidth: .infinity, alignment: .leading)
            
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.sand)
                        )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.ink.opacity(0.12), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete Worktree")
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
            Text(worktree.lastActivityText)
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(Theme.ink.opacity(0.55))
        }
    }
}

struct IconGrid: View {
    let buttons: [ButtonViewData]
    let onRunButton: (ButtonViewData) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(buttons, id: \.swiftUIId) { button in
                AppIconButton(button: button, onRunButton: onRunButton)
            }
        }
    }
}

struct AppIconButton: View {
    let button: ButtonViewData
    let onRunButton: (ButtonViewData) -> Void

    var body: some View {
        Button(action: { onRunButton(button) }) {
            iconView
        }
        .buttonStyle(.plain)
        .help(button.label)
        .accessibilityLabel(button.label)
    }

    @ViewBuilder
    private var iconView: some View {
        switch button.icon.source {
        case .sfSymbol(let name):
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.ocean)
        case .appBundle, .file:
            if let image = button.icon.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.4))
            }
        case .missing:
            Image(systemName: "questionmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.4))
        }
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

struct ScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                scrollView.autohidesScrollers = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = nsView.enclosingScrollView {
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                scrollView.autohidesScrollers = true
            }
        }
    }
}
