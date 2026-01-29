import Foundation

protocol GhosttyControlling: Sendable {
    func openOrFocus(projectName: String, worktreeName: String, worktreePath: String)
    func activeWorktreePath() -> String?
}

struct GhosttyController: GhosttyControlling {
    let runner: ProcessRunning

    // Base Ghostty background color (dark gray with slight blue tint)
    private static let baseColor = (r: 44, g: 46, b: 51)
    private static let tintStrength = 0.15

    func openOrFocus(projectName: String, worktreeName: String, worktreePath: String) {
        // Get the accent color for this worktree
        let (accentR, accentG, accentB) = Theme.worktreeAccentColorRGB(for: worktreeName)

        // Tint the base color towards the accent color
        let tintedR = mix(base: Self.baseColor.r, target: accentR, fraction: Self.tintStrength)
        let tintedG = mix(base: Self.baseColor.g, target: accentG, fraction: Self.tintStrength)
        let tintedB = mix(base: Self.baseColor.b, target: accentB, fraction: Self.tintStrength)

        let colorArg = "\(tintedR),\(tintedG),\(tintedB)"

        // Path to the script in the app bundle
        guard let resourcePath = Bundle.main.resourcePath else {
            print("GWM Ghostty: ERROR - Could not find app bundle resource path")
            return
        }
        let scriptPath = "\(resourcePath)/open_or_create_ghostty.sh"

        let command = ["/bin/bash", scriptPath, worktreePath, colorArg]

        print("GWM Ghostty: running script: \(command.joined(separator: " "))")
        print("GWM Ghostty: base color RGB(\(Self.baseColor.r),\(Self.baseColor.g),\(Self.baseColor.b)) + accent RGB(\(accentR),\(accentG),\(accentB)) = tinted RGB(\(tintedR),\(tintedG),\(tintedB))")
        _ = try? runner.run(command, currentDirectory: nil)
    }

    func activeWorktreePath() -> String? {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("GWM Ghostty: ERROR - Could not find app bundle resource path")
            return nil
        }
        let scriptPath = "\(resourcePath)/open_or_create_ghostty.sh"

        do {
            let result = try runner.run(["/bin/bash", scriptPath, "--get-active"], currentDirectory: nil)
            guard result.exitCode == 0 else { return nil }
            let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }

    private func mix(base: Int, target: Int, fraction: Double) -> Int {
        let clamped = min(max(fraction, 0.0), 1.0)
        let result = Double(base) + (Double(target) - Double(base)) * clamped
        return Int(result.rounded())
    }

}
