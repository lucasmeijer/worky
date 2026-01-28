import Foundation

struct ProjectsConfig: Codable, Equatable {
    var apps: [AppConfig]
    var projects: [ProjectConfig]

    init(apps: [AppConfig] = [], projects: [ProjectConfig]) {
        self.apps = apps
        self.projects = projects
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.apps = (try container.decodeIfPresent([AppConfig].self, forKey: .apps)) ?? []
        self.projects = (try container.decodeIfPresent([ProjectConfig].self, forKey: .projects)) ?? []
    }
}

struct ProjectConfig: Codable, Equatable {
    var bareRepoPath: String
    var apps: [AppConfig]

    init(bareRepoPath: String, apps: [AppConfig] = []) {
        self.bareRepoPath = bareRepoPath
        self.apps = apps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bareRepoPath = try container.decode(String.self, forKey: .bareRepoPath)
        self.apps = (try container.decodeIfPresent([AppConfig].self, forKey: .apps)) ?? []
    }
}

struct AppConfig: Codable, Equatable {
    var id: String?
    var label: String
    var icon: IconSpec?
    var command: [String]
}

protocol FileSystem {
    func fileExists(at url: URL) -> Bool
    func createDirectory(at url: URL) throws
    func readFile(at url: URL) throws -> Data
    func writeFile(_ data: Data, to url: URL) throws
    func attributesOfItem(at url: URL) throws -> [FileAttributeKey: Any]
}

struct LocalFileSystem: FileSystem {
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func readFile(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func writeFile(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    func attributesOfItem(at url: URL) throws -> [FileAttributeKey: Any] {
        try FileManager.default.attributesOfItem(atPath: url.path)
    }
}

struct ProjectsConfigStore: ProjectsConfigStoring {
    let baseDirectory: URL
    let fileSystem: FileSystem

    var configURL: URL {
        baseDirectory.appendingPathComponent("projects.json")
    }

    func load() throws -> ProjectsConfig {
        if fileSystem.fileExists(at: configURL) {
            let data = try fileSystem.readFile(at: configURL)
            return try JSONDecoder().decode(ProjectsConfig.self, from: data)
        }

        try fileSystem.createDirectory(at: baseDirectory)
        let defaultConfig = ProjectsConfig(apps: [], projects: [])
        let data = try JSONEncoder().encode(defaultConfig)
        try fileSystem.writeFile(data, to: configURL)
        return defaultConfig
    }
}
