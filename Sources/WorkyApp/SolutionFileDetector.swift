import Foundation

struct SolutionFileDetector {
    static let riderAppPath = "/Applications/Rider.app"
    private static let maxSearchDepth = 10
    private static let solutionExtensions = ["sln", "slnx"]

    /// Checks if Rider is installed on the system
    static func isRiderInstalled() -> Bool {
        FileManager.default.fileExists(atPath: riderAppPath)
    }

    /// Finds the solution file (.sln or .slnx) closest to the repository root
    /// - Parameter repoPath: The absolute path to the repository
    /// - Returns: The relative path to the solution file, or nil if none found
    static func findSolutionFile(in repoPath: String) -> String? {
        let fileManager = FileManager.default

        // Standardize the repo path to resolve symlinks (e.g., /tmp -> /private/tmp on macOS)
        let repoURL = URL(fileURLWithPath: repoPath, isDirectory: true)
        let standardRepoPath = repoURL.standardizedFileURL.path

        guard let enumerator = fileManager.enumerator(
            at: repoURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var bestMatch: (path: String, depth: Int)?

        for case let fileURL as URL in enumerator {
            // Calculate depth relative to repo root using standardized paths
            let standardFilePath = fileURL.standardizedFileURL.path
            guard standardFilePath.hasPrefix(standardRepoPath + "/") else {
                // File is at repo root
                let fileName = fileURL.lastPathComponent
                let depth = 0

                // Check if this is a solution file
                let fileExtension = fileURL.pathExtension.lowercased()
                if solutionExtensions.contains(fileExtension) {
                    if bestMatch == nil || (depth == bestMatch!.depth && fileName < bestMatch!.path) {
                        bestMatch = (fileName, depth)
                        break // Found at root level, can stop
                    }
                }
                continue
            }

            let relativePath = String(standardFilePath.dropFirst(standardRepoPath.count + 1))
            let depth = relativePath.components(separatedBy: "/").count - 1

            // Skip if too deep
            if depth >= maxSearchDepth {
                enumerator.skipDescendants()
                continue
            }

            // Check if this is a directory we should skip
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
               resourceValues.isDirectory == true {
                let directoryName = fileURL.lastPathComponent
                if shouldSkipDirectory(directoryName) {
                    enumerator.skipDescendants()
                }
                continue
            }

            // Check if this is a solution file
            let fileExtension = fileURL.pathExtension.lowercased()
            if solutionExtensions.contains(fileExtension) {
                // Update best match if this is shallower, or same depth but alphabetically first
                if bestMatch == nil ||
                   depth < bestMatch!.depth ||
                   (depth == bestMatch!.depth && relativePath < bestMatch!.path) {
                    bestMatch = (relativePath, depth)

                    // If we found one at root level, we can stop searching
                    if depth == 0 {
                        break
                    }
                }
            }
        }

        return bestMatch?.path
    }

    /// Determines if a directory should be skipped during search
    private static func shouldSkipDirectory(_ name: String) -> Bool {
        let ignoredDirectories = [
            ".git",
            "node_modules",
            "bin",
            "obj",
            "packages",
            ".build",
            "build",
            "Build",
            "Debug",
            "Release",
            "TestResults",
            ".vs"
        ]

        return ignoredDirectories.contains(name) || name.hasPrefix(".")
    }
}
