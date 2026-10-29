import Foundation

public struct APFSSnapshotReport: Sendable, Equatable {
    public let snapshotCount: Int
    public let snapshotNames: [String]

    public var hasSnapshots: Bool {
        snapshotCount > 0
    }

    public var explanation: String {
        guard hasSnapshots else { return "" }
        let countStr = "\(snapshotCount) local Time Machine snapshot\(snapshotCount == 1 ? "" : "s")"
        return "macOS has \(countStr) on this volume. Space from deleted files may remain allocated until macOS purges older snapshots."
    }
}

public enum APFSSnapshotInspector {
    public static func parseSnapshotOutput(_ output: String) -> APFSSnapshotReport {
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var names = [String]()
        for line in lines {
            if line.contains("com.apple.TimeMachine") || line.hasPrefix("com.apple.os.update") {
                names.append(line)
            }
        }
        return APFSSnapshotReport(snapshotCount: names.count, snapshotNames: names)
    }

    public static func checkLocalSnapshots() -> APFSSnapshotReport {
        let res = ProcessInspector.runCommand(["/usr/bin/tmutil", "listlocalsnapshots", "/"], timeout: 10)
        if res.exitCode == 0 {
            return parseSnapshotOutput(res.stdout)
        }
        return APFSSnapshotReport(snapshotCount: 0, snapshotNames: [])
    }
}
