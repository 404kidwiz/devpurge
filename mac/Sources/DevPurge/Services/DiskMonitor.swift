import Foundation

public struct DiskSpace: Sendable, Equatable {
    public let total: Int64
    public let free: Int64

    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    public var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
    }

    public var usedFraction: Double {
        guard total > 0 else { return 0 }
        let used = Double(total - free)
        return max(0.0, min(1.0, used / Double(total)))
    }

    public var freeFraction: Double {
        guard total > 0 else { return 0 }
        return max(0.0, min(1.0, Double(free) / Double(total)))
    }
}

public enum DiskMonitor {
    public static func getDiskSpace(for url: URL = FileManager.default.homeDirectoryForCurrentUser) -> DiskSpace {
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
            return DiskSpace(total: total, free: free)
        } catch {
            var stat = statvfs()
            if statvfs(url.path, &stat) == 0 {
                let total = Int64(stat.f_blocks) * Int64(stat.f_frsize)
                let free = Int64(stat.f_bavail) * Int64(stat.f_frsize)
                return DiskSpace(total: total, free: free)
            }
            return DiskSpace(total: 0, free: 0)
        }
    }
}
