import XCTest
@testable import DevPurge

final class DevPurgeEngineTests: XCTestCase {

    func testAppVersionComparison() {
        let v1 = AppVersion("26.908.40834")!
        let v2 = AppVersion("26.915.31945")!
        let v3 = AppVersion("26.915.31945")!

        XCTAssertTrue(v1 < v2)
        XCTAssertFalse(v2 < v1)
        XCTAssertEqual(v2, v3)

        let shortVer = AppVersion("1.18")!
        let longVer = AppVersion("1.18.23")!
        XCTAssertTrue(shortVer < longVer)

        XCTAssertNil(AppVersion("invalid-version"))
        XCTAssertNil(AppVersion("1.0.0-beta"))
    }

    func testTargetModel() {
        let target = Target(
            path: "/Users/test/Library/Caches/com.example/Cache",
            category: "browsers",
            status: .eligible,
            reason: "Inactive cache; can be regenerated",
            sizeBytes: 1024 * 1024 * 50
        )

        XCTAssertEqual(target.displayName, "Cache")
        XCTAssertEqual(target.status.badgeLabel, "Eligible")
        XCTAssertEqual(target.category, "browsers")
        XCTAssertNotNil(target.formattedSize)
    }

    func testFriendlyTitlesDistinguishDuplicateFolderNames() {
        let chromeCode = Target(path: "/Users/me/Library/Caches/Google/Chrome/Default/Code Cache", category: "browsers")
        let browserOSCache = Target(path: "/Users/me/Library/Caches/BrowserOS/Profile 2/Cache", category: "browsers")
        let zcodeZip = Target(path: "/Users/me/Library/Caches/@zcodedesktop-updater/update.zip", category: "installers")
        let pnpmStore = Target(path: "/Users/me/Library/pnpm/store/v11", category: "oldstores")
        let npmCache = Target(path: "/Users/me/.npm/_cacache", category: "review")
        let simDevices = Target(path: "/Users/me/Library/Developer/CoreSimulator/Devices", category: "review")
        let projModules = Target(path: "/Users/me/Work/acme-web/node_modules", category: "projects")

        XCTAssertEqual(chromeCode.friendlyTitle, "Google Chrome · Code Cache")
        XCTAssertEqual(browserOSCache.friendlyTitle, "BrowserOS (Profile 2) · Cache")
        XCTAssertEqual(zcodeZip.friendlyTitle, "ZCode Updater · update.zip")
        XCTAssertEqual(pnpmStore.friendlyTitle, "pnpm Store · v11")
        XCTAssertEqual(npmCache.friendlyTitle, "npm Cache (_cacache)")
        XCTAssertEqual(simDevices.friendlyTitle, "Xcode Simulator Devices")
        XCTAssertEqual(projModules.friendlyTitle, "acme-web · node_modules")
    }

    func testReviewTargetNativePruneAndCLISuggestions() {
        let uvCache = Target(path: "/Users/me/.cache/uv", category: "review", status: .review)
        XCTAssertEqual(uvCache.nativePruneSpec?.label, "Prune unused (uv cache prune)")
        XCTAssertEqual(uvCache.nativePruneSpec?.command, ["uv", "cache", "prune"])
        XCTAssertEqual(uvCache.cliSuggestion, "devpurge --uv")

        let npmCache = Target(path: "/Users/me/.npm/_cacache", category: "review", status: .review)
        XCTAssertEqual(npmCache.nativePruneSpec?.label, "Verify & GC (npm cache verify)")
        XCTAssertEqual(npmCache.cliSuggestion, "devpurge --node")

        let pnpmStore = Target(path: "/Users/me/Library/pnpm/store/v10", category: "review", status: .review)
        XCTAssertEqual(pnpmStore.nativePruneSpec?.label, "Prune unreferenced (pnpm store prune)")
        XCTAssertEqual(pnpmStore.cliSuggestion, "devpurge --node")

        let simDevices = Target(path: "/Users/me/Library/Developer/CoreSimulator/Devices", category: "review", status: .review)
        XCTAssertEqual(simDevices.nativePruneSpec?.label, "Prune unavailable (simctl delete unavailable)")
        XCTAssertEqual(simDevices.nativePruneSpec?.command, ["xcrun", "simctl", "delete", "unavailable"])
        XCTAssertEqual(simDevices.cliSuggestion, "xcrun simctl delete unavailable")

        let dockerRaw = Target(path: "/Users/me/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw", category: "review", status: .review)
        XCTAssertNil(dockerRaw.nativePruneSpec)
        XCTAssertEqual(dockerRaw.cliSuggestion, "docker system df")
    }

    func testStaleProjectScannerClassifiesIdleAndActiveProjects() throws {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("devpurge-proj-\(UUID().uuidString)")
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempRoot) }

        // Stale Node project (modified 30 days ago)
        let staleProj = tempRoot.appendingPathComponent("stale-web")
        let staleModules = staleProj.appendingPathComponent("node_modules")
        try fm.createDirectory(at: staleModules, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: staleProj.appendingPathComponent("package.json"))
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 86400)
        try fm.setAttributes([.modificationDate: thirtyDaysAgo], ofItemAtPath: staleModules.path)
        try fm.setAttributes([.modificationDate: thirtyDaysAgo], ofItemAtPath: staleProj.path)

        // Recent Python project (modified today)
        let recentProj = tempRoot.appendingPathComponent("recent-api")
        let recentVenv = recentProj.appendingPathComponent(".venv")
        try fm.createDirectory(at: recentVenv, withIntermediateDirectories: true)
        try Data("home = /usr/bin".utf8).write(to: recentVenv.appendingPathComponent("pyvenv.cfg"))

        var config = DevPurgeConfig()
        config.projectScanRoots = [tempRoot.path]
        config.staleProjectDays = 14

        let scanner = TargetScanner(homeDirectory: tempRoot)
        let results = scanner.collectProjectTargets(config: config)
        XCTAssertEqual(results.count, 2)

        let staleTarget = results.first { $0.path.hasSuffix("/stale-web/node_modules") }
        XCTAssertEqual(staleTarget?.status, .eligible)
        XCTAssertEqual(staleTarget?.friendlyTitle, "stale-web · node_modules")

        let recentTarget = results.first { $0.path.hasSuffix("/recent-api/.venv") }
        XCTAssertEqual(recentTarget?.status, .review)
        XCTAssertEqual(recentTarget?.friendlyTitle, "recent-api · .venv")
    }

    func testProcessInspectorDoesNotDeadlockOnLargeStdout() {
        let inspector = ProcessInspector()
        inspector.refresh()
        XCTAssertEqual(inspector.activityError, "", "ps -axo args= should succeed without pipe-buffer deadlock")
        XCTAssertFalse(inspector.processes.isEmpty)
    }

    func testConfigDefaultsAndIgnore() throws {
        var config = DevPurgeConfig()
        XCTAssertFalse(config.automatedSweep)
        XCTAssertFalse(config.rescueMode)
        XCTAssertEqual(config.intervalDays, 7)
        XCTAssertEqual(config.staleProjectDays, 14)
        XCTAssertEqual(config.lowDiskAlertThresholdGB, 25)
        XCTAssertTrue(config.ignore.isEmpty)
        XCTAssertTrue(config.projectScanRoots.isEmpty)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("devpurge-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try config.addIgnore(category: "test_category", homeDirectory: tempDir)
        try config.addProjectRoot("/tmp/my-projects", homeDirectory: tempDir)
        XCTAssertTrue(config.ignore.contains("test_category"))
        XCTAssertTrue(config.projectScanRoots.contains("/tmp/my-projects"))

        let loaded = DevPurgeConfig.load(from: tempDir)
        XCTAssertTrue(loaded.ignore.contains("test_category"))
        XCTAssertTrue(loaded.projectScanRoots.contains("/tmp/my-projects"))
    }

    func testDiskSpace() {
        let disk = DiskMonitor.getDiskSpace()
        XCTAssertGreaterThan(disk.total, 0)
        XCTAssertGreaterThan(disk.free, 0)
        XCTAssertLessThanOrEqual(disk.free, disk.total)
        XCTAssertGreaterThanOrEqual(disk.usedFraction, 0.0)
        XCTAssertLessThanOrEqual(disk.usedFraction, 1.0)
    }

    func testAPFSSnapshotInspectorParsing() {
        let sampleOutput = """
        Snapshots for disk /:
        com.apple.TimeMachine.2026-09-20-142010.local
        com.apple.TimeMachine.2026-09-21-081023.local
        """
        let report = APFSSnapshotInspector.parseSnapshotOutput(sampleOutput)
        XCTAssertEqual(report.snapshotCount, 2)
        XCTAssertTrue(report.hasSnapshots)
        XCTAssertTrue(report.explanation.contains("2 local Time Machine snapshots"))

        let emptyReport = APFSSnapshotInspector.parseSnapshotOutput("Snapshots for disk /:\n")
        XCTAssertEqual(emptyReport.snapshotCount, 0)
        XCTAssertFalse(emptyReport.snapshotCount > 0)
        XCTAssertEqual(emptyReport.explanation, "")
    }

    func testOnlyOwningAppsUpdaterBlocksCleanup() {
        let bundle = "ai.perplexity.comet"
        let appPaths = ["/Applications/Comet.app"]
        // Regression: Tailscale's Sparkle updater marked every cache on the Mac in-use.
        let unrelated = """
        /Applications/Tailscale.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate io.tailscale.ipn.macsys /Users/me me
        /Users/me/Library/Caches/com.other.app.ShipIt/ShipIt
        /Applications/Comet.app/Contents/MacOS/Comet
        """
        XCTAssertFalse(ProcessInspector.updaterRunning(processes: unrelated, bundle: bundle, appPaths: appPaths))

        for owning in [
            "/x/Sparkle.framework/Versions/B/Autoupdate ai.perplexity.comet /Users/me me",
            "/Users/me/Library/Caches/ai.perplexity.comet.ShipIt/ShipIt",
            "/Users/me/Library/Caches/x/org.sparkle-project.Sparkle/Launcher/a/Updater.app/Contents/MacOS/Updater /Applications/Comet.app 1",
        ] {
            XCTAssertTrue(ProcessInspector.updaterRunning(processes: owning, bundle: bundle, appPaths: appPaths), owning)
        }
    }

}
