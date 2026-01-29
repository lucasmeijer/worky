import XCTest
@testable import WorkyApp

final class SolutionFileDetectorTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testIsRiderInstalled() {
        // This test checks if the method correctly detects Rider installation
        // The actual result depends on whether Rider is installed on the test machine
        let isInstalled = SolutionFileDetector.isRiderInstalled()
        let riderExists = FileManager.default.fileExists(atPath: SolutionFileDetector.riderAppPath)
        XCTAssertEqual(isInstalled, riderExists, "isRiderInstalled should match file existence check")
    }

    func testFindsSolutionFileInRoot() throws {
        // Create a .sln file in the root
        let slnFile = tempDir.appendingPathComponent("TestProject.sln")
        try "".write(to: slnFile, atomically: true, encoding: .utf8)

        let result = SolutionFileDetector.findSolutionFile(in: tempDir.path)
        XCTAssertEqual(result, "TestProject.sln")
    }

    func testFindsSlnxFiles() throws {
        // Create a .slnx file
        let slnxFile = tempDir.appendingPathComponent("TestProject.slnx")
        try "".write(to: slnxFile, atomically: true, encoding: .utf8)

        let result = SolutionFileDetector.findSolutionFile(in: tempDir.path)
        XCTAssertEqual(result, "TestProject.slnx")
    }

    func testFindsSolutionFileInSubfolder() throws {
        // Create a .sln file in a subfolder
        let srcDir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        let slnFile = srcDir.appendingPathComponent("Project.sln")
        try "".write(to: slnFile, atomically: true, encoding: .utf8)

        let result = SolutionFileDetector.findSolutionFile(in: tempDir.path)
        XCTAssertEqual(result, "src/Project.sln")
    }

    func testPrefersShallowestFile() throws {
        // Create solution files at different depths
        let rootSln = tempDir.appendingPathComponent("Root.sln")
        try "".write(to: rootSln, atomically: true, encoding: .utf8)

        let deepDir = tempDir.appendingPathComponent("src/deep")
        try FileManager.default.createDirectory(at: deepDir, withIntermediateDirectories: true)
        let deepSln = deepDir.appendingPathComponent("Deep.sln")
        try "".write(to: deepSln, atomically: true, encoding: .utf8)

        let result = SolutionFileDetector.findSolutionFile(in: tempDir.path)
        XCTAssertEqual(result, "Root.sln", "Should prefer solution file closest to root")
    }

    func testPrefersShallowestThenAlphabetical() throws {
        // Create two solution files at the same depth
        let srcDir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)

        let slnB = srcDir.appendingPathComponent("B.sln")
        try "".write(to: slnB, atomically: true, encoding: .utf8)

        let slnA = srcDir.appendingPathComponent("A.sln")
        try "".write(to: slnA, atomically: true, encoding: .utf8)

        let result = SolutionFileDetector.findSolutionFile(in: tempDir.path)
        XCTAssertEqual(result, "src/A.sln", "Should prefer alphabetically first when depth is the same")
    }

    func testSkipsIgnoredDirectories() throws {
        // Create solution files in ignored directories
        let gitDir = tempDir.appendingPathComponent(".git/hooks")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        let gitSln = gitDir.appendingPathComponent("Git.sln")
        try "".write(to: gitSln, atomically: true, encoding: .utf8)

        let binDir = tempDir.appendingPathComponent("bin/Debug")
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        let binSln = binDir.appendingPathComponent("Bin.sln")
        try "".write(to: binSln, atomically: true, encoding: .utf8)

        let objDir = tempDir.appendingPathComponent("obj/Release")
        try FileManager.default.createDirectory(at: objDir, withIntermediateDirectories: true)
        let objSln = objDir.appendingPathComponent("Obj.sln")
        try "".write(to: objSln, atomically: true, encoding: .utf8)

        // Create a valid solution file outside ignored directories
        let validSln = tempDir.appendingPathComponent("Valid.sln")
        try "".write(to: validSln, atomically: true, encoding: .utf8)

        let result = SolutionFileDetector.findSolutionFile(in: tempDir.path)
        XCTAssertEqual(result, "Valid.sln", "Should skip .git, bin, and obj directories")
    }

    func testReturnsNilWhenNoSolutionFile() {
        // Create some files but no solution files
        let txtFile = tempDir.appendingPathComponent("readme.txt")
        try? "".write(to: txtFile, atomically: true, encoding: .utf8)

        let result = SolutionFileDetector.findSolutionFile(in: tempDir.path)
        XCTAssertNil(result, "Should return nil when no solution files exist")
    }

    func testReturnsRelativePath() throws {
        // Create a solution file in a nested directory
        let nestedDir = tempDir.appendingPathComponent("source/projects")
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        let slnFile = nestedDir.appendingPathComponent("MyProject.sln")
        try "".write(to: slnFile, atomically: true, encoding: .utf8)

        let result = SolutionFileDetector.findSolutionFile(in: tempDir.path)
        XCTAssertEqual(result, "source/projects/MyProject.sln", "Should return relative path from repo root")
        XCTAssertFalse(result?.hasPrefix("/") ?? true, "Should not return absolute path")
    }

    func testSkipsNodeModules() throws {
        // Create solution file in node_modules
        let nodeModules = tempDir.appendingPathComponent("node_modules/package")
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        let nodeSln = nodeModules.appendingPathComponent("Node.sln")
        try "".write(to: nodeSln, atomically: true, encoding: .utf8)

        // Create valid solution file
        let validSln = tempDir.appendingPathComponent("App.sln")
        try "".write(to: validSln, atomically: true, encoding: .utf8)

        let result = SolutionFileDetector.findSolutionFile(in: tempDir.path)
        XCTAssertEqual(result, "App.sln", "Should skip node_modules directory")
    }

    func testSkipsPackagesDirectory() throws {
        // Create solution file in packages directory (NuGet)
        let packages = tempDir.appendingPathComponent("packages/SomePackage")
        try FileManager.default.createDirectory(at: packages, withIntermediateDirectories: true)
        let pkgSln = packages.appendingPathComponent("Package.sln")
        try "".write(to: pkgSln, atomically: true, encoding: .utf8)

        // Create valid solution file
        let validSln = tempDir.appendingPathComponent("MyApp.sln")
        try "".write(to: validSln, atomically: true, encoding: .utf8)

        let result = SolutionFileDetector.findSolutionFile(in: tempDir.path)
        XCTAssertEqual(result, "MyApp.sln", "Should skip packages directory")
    }
}
