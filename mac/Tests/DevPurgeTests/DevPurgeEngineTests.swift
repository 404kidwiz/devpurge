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

    func testConfigDefaultsAndIgnore() throws {
        var config = DevPurgeConfig()
        XCTAssertFalse(config.automatedSweep)
        XCTAssertFalse(config.rescueMode)
        XCTAssertEqual(config.intervalDays, 7)
        XCTAssertTrue(config.ignore.isEmpty)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("devpurge-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try config.addIgnore(category: "test_category", homeDirectory: tempDir)
        XCTAssertTrue(config.ignore.contains("test_category"))

        let loaded = DevPurgeConfig.load(from: tempDir)
        XCTAssertTrue(loaded.ignore.contains("test_category"))
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
        XCTAssertFalse(emptyReport.hasSnapshots)
        XCTAssertEqual(emptyReport.explanation, "")
    }

}
