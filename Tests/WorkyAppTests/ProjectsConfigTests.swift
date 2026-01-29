import XCTest
@testable import WorkyApp

final class ProjectsConfigTests: XCTestCase {
    func testDecodesProjectsConfigApps() throws {
        let json = """
        {
          "apps": [
            {
              "id": "ghostty",
              "label": "Ghostty",
              "icon": { "type": "file", "path": "/Applications/Ghostty.app" },
              "command": ["open", "-a", "Ghostty.app", "--args", "--working-directory=$WORKTREE"]
            }
          ],
          "projects": [
            {
              "bareRepoPath": "~/Curiosity",
              "apps": [
                {
                  "id": "rider",
                  "label": "Rider",
                  "icon": { "type": "file", "path": "/Applications/Rider.app" },
                  "command": ["open", "-a", "Rider", "$WORKTREE/Subito/Subito.slnx"]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(ProjectsConfig.self, from: json)

        XCTAssertEqual(config.apps.count, 1)
        XCTAssertEqual(config.projects.count, 1)
        XCTAssertEqual(config.projects[0].apps.count, 1)
        XCTAssertEqual(config.apps[0].label, "Ghostty")
        XCTAssertEqual(config.projects[0].apps[0].label, "Rider")
    }

    func testDefaultsMissingAppsToEmpty() throws {
        let json = """
        { "projects": [ { "bareRepoPath": "~/Curiosity" } ] }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(ProjectsConfig.self, from: json)
        XCTAssertEqual(config.apps.count, 0)
        XCTAssertEqual(config.projects.count, 1)
        XCTAssertEqual(config.projects[0].apps.count, 0)
    }
}
