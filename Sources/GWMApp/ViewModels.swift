import Foundation
import SwiftUI

struct ProjectViewData: Identifiable {
    let id: String
    let name: String
    let repoPath: String
    let gitDirPath: String
    let worktrees: [WorktreeViewData]
}

struct WorktreeViewData: Identifiable {
    let id: String
    let name: String
    let path: String
    let lastActivityText: String
    let buttons: [ButtonViewData]
}

struct ButtonViewData: Identifiable {
    let id: String
    let label: String
    let icon: IconPayload
    let command: [String]

    var stableId: String { id }

    var swiftUIId: String { id + label }

    var swiftUIImage: Image {
        switch icon.source {
        case .sfSymbol(let name):
            return Image(systemName: name)
        case .appBundle, .file:
            if let image = icon.image {
                return Image(nsImage: image)
            }
            return Image(systemName: "questionmark")
        case .missing:
            return Image(systemName: "questionmark")
        }
    }
}

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published var projects: [ProjectViewData] = []
    @Published var errorMessage: String?

    private let loader: ProjectsLoader
    private let iconResolver: IconResolver
    private let ghosttyController: GhosttyControlling
    private let commandExecutor: CommandExecuting
    private let gitClient: GitClienting
    private let cityPicker: CityNamePicker
    private let worktreeRoot: URL

    init(
        loader: ProjectsLoader,
        iconResolver: IconResolver,
        ghosttyController: GhosttyControlling,
        commandExecutor: CommandExecuting,
        gitClient: GitClienting,
        cityPicker: CityNamePicker = CityNamePicker(),
        worktreeRoot: URL = ConfigPaths.worktreeRoot
    ) {
        self.loader = loader
        self.iconResolver = iconResolver
        self.ghosttyController = ghosttyController
        self.commandExecutor = commandExecutor
        self.gitClient = gitClient
        self.cityPicker = cityPicker
        self.worktreeRoot = worktreeRoot
    }

    func load() {
        Task { await refresh() }
    }

    func refresh() async {
        errorMessage = nil
        do {
            let items = try loader.loadProjects()
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let now = Date()
            let nextProjects = items.map { project in
                ProjectViewData(
                    id: project.id,
                    name: project.name,
                    repoPath: project.repoPath,
                    gitDirPath: project.gitDirPath,
                    worktrees: project.worktrees.map { worktree in
                        WorktreeViewData(
                            id: worktree.id,
                            name: worktree.name,
                            path: worktree.path,
                            lastActivityText: formatter.localizedString(for: worktree.lastActivity, relativeTo: now),
                            buttons: worktree.buttons.map { button in
                                ButtonViewData(
                                    id: button.id,
                                    label: button.label,
                                    icon: iconResolver.resolve(button.icon),
                                    command: button.command
                                )
                            }
                        )
                    }
                )
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                projects = nextProjects
            }
        } catch {
            handleError(error)
        }
    }

    func createWorktree(for project: ProjectViewData) {
        Task {
            do {
                print("GWM action: create worktree for \(project.name)")
                let usedNames = Set(project.worktrees.map { $0.name })
                let city = cityPicker.pick(used: usedNames)
                let projectRoot = worktreeRoot.appendingPathComponent(project.name)
                try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
                let worktreePath = projectRoot.appendingPathComponent(city).path
                try gitClient.addWorktree(bareRepoPath: project.gitDirPath, path: worktreePath, branchName: city)
                await refresh()
            } catch {
                handleError(error)
            }
        }
    }

    func removeWorktree(_ worktree: WorktreeViewData, from project: ProjectViewData) {
        Task {
            do {
                print("GWM action: remove worktree \(worktree.path)")
                try gitClient.removeWorktree(bareRepoPath: project.gitDirPath, path: worktree.path)
                await refresh()
            } catch {
                handleError(error)
            }
        }
    }

    func runButton(_ button: ButtonViewData, worktree: WorktreeViewData, project: ProjectViewData) {
        print("GWM action: run button \(button.id) for \(worktree.name)")
        if button.id == "ghostty" {
            ghosttyController.openOrFocus(
                projectName: project.name,
                worktreeName: worktree.name,
                worktreePath: worktree.path
            )
            return
        }
        Task {
            do {
                try commandExecutor.execute(button.command)
            } catch {
                handleError(error)
            }
        }
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        errorMessage = message
        print("GWM error: \(message)")
    }
}
