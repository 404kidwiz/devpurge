import XCTest
@testable import DevPurge

final class ProtectedPathsTests: XCTestCase {
    func testRefusesProtectedLocations() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("dp-home-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }
        let fm = FileManager.default
        for sub in ["Desktop", "Documents", "Projects", "Library/Keychains", "Library/Developer/Xcode/Archives/a.xcarchive",
                    "Projects/app/.git/objects", "Library/Caches/com.example"] {
            try fm.createDirectory(at: home.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        let refused = ["", "Desktop", "Documents", "Projects", "Library/Keychains",
                       "Library/Developer/Xcode/Archives/a.xcarchive", "Projects/app/.git", "Projects/app/.git/objects"]
        for sub in refused {
            let url = sub.isEmpty ? home : home.appendingPathComponent(sub)
            XCTAssertNotNil(ProtectedPaths.reason(for: url, home: home), "should refuse \(sub)")
        }
        XCTAssertNotNil(ProtectedPaths.reason(for: URL(fileURLWithPath: "/"), home: home))
        XCTAssertNotNil(ProtectedPaths.reason(for: home.deletingLastPathComponent(), home: home))
        XCTAssertNil(ProtectedPaths.reason(for: home.appendingPathComponent("Library/Caches/com.example"), home: home))
    }
}
