import Foundation

enum AppDependencies {
    @MainActor
    static func makeViewModel() -> ProjectsViewModel {
        let fileSystem = LocalFileSystem()
        let configStore = ProjectsConfigStore(baseDirectory: ConfigPaths.homeConfigDirectory, fileSystem: fileSystem)
        let processRunner = LocalProcessRunner()
        let gitClient = GitClient(runner: processRunner)
        let worktreeRoot = ConfigPaths.worktreeRoot
        let loader = ProjectsLoader(
            configStore: configStore,
            gitClient: gitClient,
            activityReader: WorktreeActivityReader(fileSystem: fileSystem),
            buttonBuilder: ButtonBuilder()
        )
        return ProjectsViewModel(
            loader: loader,
            iconResolver: IconResolver(),
            ghosttyController: GhosttyController(runner: processRunner),
            commandExecutor: CommandExecutor(runner: processRunner),
            gitClient: gitClient,
            worktreeRoot: worktreeRoot
        )
    }
}
