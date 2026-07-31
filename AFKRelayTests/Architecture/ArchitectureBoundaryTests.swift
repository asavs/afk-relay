import Foundation
import Testing

private nonisolated func architectureSourceRoot() -> URL {
    var url = URL(filePath: #filePath)
    url.deleteLastPathComponent()
    url.deleteLastPathComponent()
    url.deleteLastPathComponent()
    return url.appending(path: "AFKRelay", directoryHint: .isDirectory)
}

private nonisolated func architectureSourceTreeIsAvailable() -> Bool {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(
        atPath: architectureSourceRoot().path(),
        isDirectory: &isDirectory
    )
    return exists && isDirectory.boolValue
}

/// These checks read the checked-out sources through `#filePath`, so they can
/// only run where the build host's source tree is mounted (macOS test hosts
/// and simulators). On a physical device they must skip visibly, never pass
/// silently.
@Suite(
    "Architecture boundaries",
    .enabled(
        if: architectureSourceTreeIsAvailable(),
        "The build host's source tree is not reachable from this test runner."
    )
)
struct ArchitectureBoundaryTests {
    @Test("Gameplay and mechanics never import health or commerce frameworks")
    func gameplayFrameworkBoundary() throws {
        let sourceRoot = Self.sourceRoot

        for folder in ["Domain", "Game", "Presentation", "UI"] {
            for fileURL in try checkedSwiftFiles(in: sourceRoot, folder: folder) {
                let source = try String(contentsOf: fileURL, encoding: .utf8)
                #expect(!source.contains("import HealthKit"), "HealthKit leaked into \(fileURL.path())")
                #expect(!source.contains("import StoreKit"), "StoreKit leaked into \(fileURL.path())")
            }
        }
    }

    @Test("Mechanics do not resolve concrete presentation resources")
    func concreteResourceBoundary() throws {
        let sourceRoot = Self.sourceRoot

        for folder in ["Domain", "Game"] {
            for fileURL in try checkedSwiftFiles(in: sourceRoot, folder: folder) {
                let source = try String(contentsOf: fileURL, encoding: .utf8)
                #expect(!source.contains("SKTexture(imageNamed:"), "Texture identifier leaked into \(fileURL.path())")
                #expect(!source.contains("Image(\""), "Asset identifier leaked into \(fileURL.path())")
                #expect(!source.contains("themeID"), "Theme identifier leaked into \(fileURL.path())")
                #expect(!source.contains("catalogID"), "Catalog identifier leaked into \(fileURL.path())")
            }
        }
    }

    @Test("Only economy reconciliation writes credited or available tokens")
    func mintingBoundary() throws {
        let sourceRoot = Self.sourceRoot
        let mintingWrite = try Regex(#"lifetimeStepsCredited\s*(\+=|=(?!=))|availableTokens\s*\+="#)

        let files = try swiftFiles(below: sourceRoot)
            .filter { $0.lastPathComponent != "Economy.swift" }
        #expect(!files.isEmpty, "No production sources found below \(sourceRoot.path())")

        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            #expect(
                source.firstMatch(of: mintingWrite) == nil,
                "Token-minting write outside Domain/Economy in \(fileURL.path())"
            )
        }
    }

    private func checkedSwiftFiles(in sourceRoot: URL, folder: String) throws -> [URL] {
        let folderURL = sourceRoot.appending(path: folder, directoryHint: .isDirectory)
        #expect(
            FileManager.default.fileExists(atPath: folderURL.path()),
            "Checked source folder is missing: \(folderURL.path())"
        )

        let files = try swiftFiles(below: folderURL)
        #expect(!files.isEmpty, "Checked source folder has no Swift files: \(folderURL.path())")
        return files
    }

    private static var sourceRoot: URL {
        architectureSourceRoot()
    }

    private func swiftFiles(below root: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )
        var files: [URL] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            if values.isRegularFile == true, fileURL.pathExtension == "swift" {
                files.append(fileURL)
            }
        }

        return files.sorted { $0.path() < $1.path() }
    }
}
