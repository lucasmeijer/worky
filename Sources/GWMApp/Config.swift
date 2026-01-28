import Foundation

struct ProjectsConfig: Codable, Equatable {
    var projects: [ProjectConfig]
}

struct ProjectConfig: Codable, Equatable {
    var bareRepoPath: String
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
        let defaultConfig = ProjectsConfig(projects: [
            ProjectConfig(bareRepoPath: "~/Curiosity.git"),
            ProjectConfig(bareRepoPath: "~/life")
        ])
        let data = try JSONEncoder().encode(defaultConfig)
        try fileSystem.writeFile(data, to: configURL)
        return defaultConfig
    }
}
