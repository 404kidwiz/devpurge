import XCTest
@testable import DevPurge

/// Runs the shared tests/units_cases.json against the Swift copy of the formatter,
/// so the Mac app prints exactly what the CLI and web GUI print.
final class ByteFormatTests: XCTestCase {
    private func sharedCases() throws -> [(Int64?, String)] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // DevPurgeTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // mac
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("tests/units_cases.json")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let cases = try XCTUnwrap(json?["cases"] as? [[Any]])
        return cases.map { pair in
            ((pair[0] as? NSNumber).map { $0.int64Value }, pair[1] as! String)
        }
    }

    func testMatchesSharedCases() throws {
        let cases = try sharedCases()
        XCTAssertGreaterThan(cases.count, 10)
        for (bytes, expected) in cases {
            XCTAssertEqual(ByteFormat.string(bytes), expected, "bytes: \(String(describing: bytes))")
        }
    }

    func testTargetAndDiskUseDecimalUnits() {
        let target = Target(path: "/tmp/x", category: "browsers", sizeBytes: 5_197_000_000)
        XCTAssertEqual(target.formattedSize, "5.20 GB")
        let disk = DiskSpace(total: 994_660_000_000, free: 138_290_000_000)
        XCTAssertEqual(disk.formattedFree, "138.29 GB")
        XCTAssertEqual(disk.formattedTotal, "994.66 GB")
    }
}
