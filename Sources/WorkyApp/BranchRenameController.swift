import Foundation

protocol BranchRenameControlling: Sendable {
    func hasUpstreamBranch(forWorktreePath worktreePath: String) -> Bool
    func runRenameScript(forWorktreePath worktreePath: String) -> String?
}

struct BranchRenameController: BranchRenameControlling {
    let runner: ProcessRunning

    func hasUpstreamBranch(forWorktreePath worktreePath: String) -> Bool {
        do {
            let result = try runner.run([
                "/usr/bin/env",
                "git",
                "-C",
                worktreePath,
                "rev-parse",
                "--abbrev-ref",
                "--symbolic-full-name",
                "@{u}"
            ], currentDirectory: nil)

            guard result.exitCode == 0 else {
                return false
            }

            let upstream = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return !upstream.isEmpty
        } catch {
            return false
        }
    }

    func runRenameScript(forWorktreePath worktreePath: String) -> String? {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("Worky BranchRename: ERROR - Could not find app bundle resource path")
            return nil
        }
        let scriptPath = "\(resourcePath)/rename_branch_from_diff.sh"

        do {
            let result = try runner.run([
                "/bin/bash",
                scriptPath,
                worktreePath
            ], currentDirectory: nil)
            guard result.exitCode == 0 else {
                if !result.stderr.isEmpty {
                    print("Worky BranchRename: script failed: \(result.stderr)")
                }
                return nil
            }
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !output.isEmpty else { return nil }
            if output.lowercased() == "no" { return nil }
            return output
        } catch {
            print("Worky BranchRename: ERROR - \(error)")
            return nil
        }
    }
}
