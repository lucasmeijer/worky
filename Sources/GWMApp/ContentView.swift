import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel: ProjectsViewModel
    @State private var appear = false
    @State private var showingAddProject = false
    @State private var draggingProject: ProjectViewData?

    init(viewModel: ProjectsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Theme.coral)
                }
                ForEach(viewModel.projects) { project in
                    projectSection(for: project)
                }

                addProjectButton
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(Double(viewModel.projects.count) * 0.08), value: appear)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshStatsOnActivation()
        }
    }

    @ViewBuilder
    private func projectSection(for project: ProjectViewData) -> some View {
        ProjectSection(
            project: project,
            draggingProject: $draggingProject,
            onAddWorktree: { viewModel.createWorktree(for: project) },
            onRemoveWorktree: { worktree in viewModel.removeWorktree(worktree, from: project) },
            onRemoveProject: { viewModel.removeProject(project) },
            onRunButton: { button, worktree in
                viewModel.runButton(button, worktree: worktree, project: project)
            },
            onReorder: viewModel.reorderProjects
        )
        .opacity(draggingProject?.id == project.id ? 0.5 : 1.0)
        .onDrag {
            draggingProject = project
            return NSItemProvider(object: project.id as NSString)
        }
        .onDrop(of: [.plainText], delegate: ProjectDropDelegate(
            project: project,
            draggingProject: $draggingProject,
            onReorder: viewModel.reorderProjects
        ))
    }

    private var addProjectButton: some View {
        Button(action: { showingAddProject = true }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("add project")
                    .font(.custom("Avenir Next", size: 14))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Theme.ink.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .fileImporter(
            isPresented: $showingAddProject,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.addProject(at: url.path)
                }
            case .failure(let error):
                print("GWM error selecting folder: \(error)")
            }
        }
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
    @Binding var draggingProject: ProjectViewData?
    let onAddWorktree: () -> Void
    let onRemoveWorktree: (WorktreeViewData) -> Void
    let onRemoveProject: () -> Void
    let onRunButton: (ButtonViewData, WorktreeViewData) -> Void
    let onReorder: ([ProjectViewData]) -> Void
    @State private var deleteTarget: WorktreeViewData?
    @State private var showingRemoveProjectConfirmation = false
    @State private var isHoveringTitle = false
    @State private var isHoveringXButton = false
    @State private var isHoveringNewWorktree = false
    @State private var isPressedNewWorktree = false

    var body: some View {
        VStack(spacing: 12) {
            header
            VStack(spacing: 12) {
                ForEach(project.worktrees) { worktree in
                    WorktreeRow(
                        worktree: worktree,
                        onRemove: { handleRemove(worktree) },
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
        .alert("Remove project from list?", isPresented: $showingRemoveProjectConfirmation) {
            Button("Remove", role: .destructive) {
                onRemoveProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will only remove the project from Worky. No repositories or worktrees will be deleted from disk.")
        }
    }

    private func handleRemove(_ worktree: WorktreeViewData) {
        // Skip confirmation if worktree is clean and has no unmerged commits
        if case .loaded(let stats) = worktree.statsState,
           stats.isClean && stats.unmergedCommits == 0 {
            onRemoveWorktree(worktree)
        } else {
            deleteTarget = worktree
        }
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Text(project.name)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onHover { hovering in
                        isHoveringTitle = hovering
                        if hovering {
                            NSCursor.openHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }

                Button(action: { showingRemoveProjectConfirmation = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(isHoveringXButton ? 0.7 : 0.4))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Project")
                .onHover { hovering in
                    isHoveringXButton = hovering
                }
            }
            Button(action: onAddWorktree) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("New Worktree")
                        .font(.custom("Avenir Next", size: 14))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Theme.ink.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.sand.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(newWorktreeOutlineColor, lineWidth: newWorktreeOutlineWidth)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringNewWorktree = hovering
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressedNewWorktree = true }
                    .onEnded { _ in isPressedNewWorktree = false }
            )
            .accessibilityLabel("New Worktree")
        }
    }

    private var newWorktreeOutlineColor: Color {
        if isPressedNewWorktree {
            return Theme.ink.opacity(0.4)
        } else if isHoveringNewWorktree {
            return Theme.ink.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    private var newWorktreeOutlineWidth: CGFloat {
        (isHoveringNewWorktree || isPressedNewWorktree) ? 2 : 0
    }
}

struct WorktreeRow: View {
    let worktree: WorktreeViewData
    let onRemove: () -> Void
    let onRunButton: (ButtonViewData) -> Void
    @State private var isTrashHovering = false
    @State private var isTrashPressed = false

    var body: some View {
        HStack() {
            titleBlock
            Spacer();
            ForEach(worktree.buttons, id: \.swiftUIId) { button in
                AppIconButton(button: button, onRunButton: onRunButton)
            }
            
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(trashOutlineColor, lineWidth: trashOutlineWidth)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete Worktree")
            .onHover { hovering in
                isTrashHovering = hovering
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isTrashPressed = true }
                    .onEnded { _ in isTrashPressed = false }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.worktreeRowBackgroundGradient(for: worktree.name), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
        )
    }

    private var trashOutlineColor: Color {
        if isTrashPressed {
            return Theme.ink.opacity(0.4)
        } else if isTrashHovering {
            return Theme.ink.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    private var trashOutlineWidth: CGFloat {
        (isTrashHovering || isTrashPressed) ? 2 : 0
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(worktree.branchName)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.ink)
            metadataLine
                .font(.custom("Avenir Next", size: 11))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            Text(worktree.lastActivityText)
                .foregroundColor(Theme.ink.opacity(0.55))
            metadataDetail
        }
    }

    @ViewBuilder
    private var metadataDetail: some View {
        switch worktree.statsState {
        case .loading:
            HStack(spacing: 6) {
                Text("•")
                    .foregroundColor(Theme.ink.opacity(0.45))
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
            }
        case .loaded(let stats):
            HStack(spacing: 6) {
                Text("• \(stats.unmergedCommitsText)")
                    .foregroundColor(Theme.ink.opacity(0.45))
                Text("• \(stats.lineDeltaText)")
                    .foregroundColor(Theme.ink.opacity(0.6))
            }
        case .failed:
            HStack(spacing: 6) {
                Text("•")
                    .foregroundColor(Theme.ink.opacity(0.45))
                Text("—")
                    .foregroundColor(Theme.ink.opacity(0.45))
            }
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
    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: { onRunButton(button) }) {
            iconView
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(outlineColor, lineWidth: outlineWidth)
                )
        }
        .buttonStyle(.plain)
        .help(button.label)
        .accessibilityLabel(button.label)
        .onHover { hovering in
            isHovering = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var outlineColor: Color {
        if isPressed {
            return Theme.ink.opacity(0.4)
        } else if isHovering {
            return Theme.ink.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    private var outlineWidth: CGFloat {
        (isHovering || isPressed) ? 2 : 0
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

    private static let worktreePalette: [PaletteColor] = [
        PaletteColor(red: 1.00, green: 0.10, blue: 0.10),
        PaletteColor(red: 0.98, green: 0.48, blue: 0.00),
        PaletteColor(red: 1.00, green: 0.85, blue: 0.05),
        PaletteColor(red: 0.10, green: 0.75, blue: 0.25),
        PaletteColor(red: 0.00, green: 0.85, blue: 0.80),
        PaletteColor(red: 0.05, green: 0.45, blue: 1.00),
        PaletteColor(red: 0.30, green: 0.05, blue: 1.00),
        PaletteColor(red: 0.70, green: 0.05, blue: 0.95),
        PaletteColor(red: 1.00, green: 0.05, blue: 0.70),
        PaletteColor(red: 0.65, green: 0.20, blue: 0.05),
        PaletteColor(red: 0.10, green: 0.10, blue: 0.10),
        PaletteColor(red: 0.95, green: 0.95, blue: 0.95),
        PaletteColor(red: 0.00, green: 0.40, blue: 0.40),
        PaletteColor(red: 0.40, green: 0.80, blue: 0.00),
        PaletteColor(red: 0.00, green: 0.60, blue: 1.00),
        PaletteColor(red: 1.00, green: 0.55, blue: 0.85),
        PaletteColor(red: 0.85, green: 0.75, blue: 0.15),
        PaletteColor(red: 0.05, green: 0.20, blue: 0.80),
        PaletteColor(red: 0.80, green: 0.15, blue: 0.25),
        PaletteColor(red: 0.15, green: 0.85, blue: 0.60)
    ]
    private static let worktreeTintStrength = 0.34

    static func worktreeRowBackgroundGradient(for worktreeName: String) -> LinearGradient {
        let base = PaletteColor(red: 0.98, green: 0.96, blue: 0.92)
        guard !worktreePalette.isEmpty else {
            return LinearGradient(
                colors: [base.color, base.color],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        let index = worktreePaletteIndex(for: worktreeName)
        let accent = worktreePalette[index]
        let tinted = base.mixed(with: accent, fraction: worktreeTintStrength)
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: tinted.color, location: 0.0),
                .init(color: base.color, location: 0.5),
                .init(color: base.color, location: 1.0)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private static func worktreePaletteIndex(for worktreeName: String) -> Int {
        let hash = stableHash(worktreeName.isEmpty ? "worktree" : worktreeName)
        return Int(hash % UInt64(worktreePalette.count))
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }

    static func worktreeAccentColorRGB(for worktreeName: String) -> (Int, Int, Int) {
        guard !worktreePalette.isEmpty else {
            return (250, 245, 235) // base color
        }
        let index = worktreePaletteIndex(for: worktreeName)
        let accent = worktreePalette[index]
        return (
            Int(accent.red * 255),
            Int(accent.green * 255),
            Int(accent.blue * 255)
        )
    }

    private struct PaletteColor {
        let red: Double
        let green: Double
        let blue: Double

        func mixed(with other: PaletteColor, fraction: Double) -> PaletteColor {
            let clamped = min(max(fraction, 0.0), 1.0)
            return PaletteColor(
                red: red + (other.red - red) * clamped,
                green: green + (other.green - green) * clamped,
                blue: blue + (other.blue - blue) * clamped
            )
        }

        var color: Color {
            Color(red: red, green: green, blue: blue)
        }
    }
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

struct ProjectDropDelegate: DropDelegate {
    let project: ProjectViewData
    @Binding var draggingProject: ProjectViewData?
    let onReorder: ([ProjectViewData]) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingProject = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingProject, dragging.id != project.id else {
            return
        }
        onReorder([dragging, project])
    }
}
