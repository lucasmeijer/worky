import Foundation

protocol GhosttyControlling {
    func openOrFocus(projectName: String, worktreeName: String, worktreePath: String)
}

struct GhosttyController: GhosttyControlling {
    let runner: ProcessRunning

    // Base Ghostty background color (dark gray with slight blue tint)
    private static let baseColor = (r: 44, g: 46, b: 51)
    private static let tintStrength = 0.30

    func openOrFocus(projectName: String, worktreeName: String, worktreePath: String) {
        // Get the accent color for this worktree
        let (accentR, accentG, accentB) = Theme.worktreeAccentColorRGB(for: worktreeName)

        // Tint the base color towards the accent color
        let tintedR = mix(base: Self.baseColor.r, target: accentR, fraction: Self.tintStrength)
        let tintedG = mix(base: Self.baseColor.g, target: accentG, fraction: Self.tintStrength)
        let tintedB = mix(base: Self.baseColor.b, target: accentB, fraction: Self.tintStrength)

        let colorArg = "\(tintedR),\(tintedG),\(tintedB)"

        // Path to the script - relative to project directory
        // TODO: Make this configurable or bundle as a resource for production
        let scriptPath = "scripts/open_or_create_ghostty.sh"

        let command = ["/bin/bash", scriptPath, worktreePath, colorArg]

        print("GWM Ghostty: running script: \(command.joined(separator: " "))")
        print("GWM Ghostty: base color RGB(\(Self.baseColor.r),\(Self.baseColor.g),\(Self.baseColor.b)) + accent RGB(\(accentR),\(accentG),\(accentB)) = tinted RGB(\(tintedR),\(tintedG),\(tintedB))")
        _ = try? runner.run(command, currentDirectory: nil)
    }

    private func mix(base: Int, target: Int, fraction: Double) -> Int {
        let clamped = min(max(fraction, 0.0), 1.0)
        let result = Double(base) + (Double(target) - Double(base)) * clamped
        return Int(result.rounded())
    }
}
