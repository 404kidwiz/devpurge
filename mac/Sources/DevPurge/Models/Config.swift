import Foundation

public struct DevPurgeConfig: Codable, Sendable, Equatable {
    public var automatedSweep: Bool
    public var rescueMode: Bool
    public var ignore: [String]
    public var intervalDays: Int
    public var projectScanRoots: [String]
    public var staleProjectDays: Int
    public var lowDiskAlertThresholdGB: Int

    public init(
        automatedSweep: Bool = false,
        rescueMode: Bool = false,
        ignore: [String] = [],
        intervalDays: Int = 7,
        projectScanRoots: [String] = [],
        staleProjectDays: Int = 14,
        lowDiskAlertThresholdGB: Int = 25
    ) {
        self.automatedSweep = automatedSweep
        self.rescueMode = rescueMode
        self.ignore = ignore
        self.intervalDays = intervalDays
        self.projectScanRoots = projectScanRoots
        self.staleProjectDays = staleProjectDays
        self.lowDiskAlertThresholdGB = lowDiskAlertThresholdGB
    }

    enum CodingKeys: String, CodingKey {
        case automatedSweep = "automated_sweep"
        case rescueMode = "rescue_mode"
        case ignore
        case intervalDays = "interval_days"
        case projectScanRoots = "project_scan_roots"
        case staleProjectDays = "stale_project_days"
        case lowDiskAlertThresholdGB = "low_disk_alert_threshold_gb"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.automatedSweep = try container.decodeIfPresent(Bool.self, forKey: .automatedSweep) ?? false
        self.rescueMode = try container.decodeIfPresent(Bool.self, forKey: .rescueMode) ?? false
        self.ignore = try container.decodeIfPresent([String].self, forKey: .ignore) ?? []
        self.intervalDays = try container.decodeIfPresent(Int.self, forKey: .intervalDays) ?? 7
        self.projectScanRoots = try container.decodeIfPresent([String].self, forKey: .projectScanRoots) ?? []
        self.staleProjectDays = try container.decodeIfPresent(Int.self, forKey: .staleProjectDays) ?? 14
        self.lowDiskAlertThresholdGB = try container.decodeIfPresent(Int.self, forKey: .lowDiskAlertThresholdGB) ?? 25
    }

    public static func load(from homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> DevPurgeConfig {
        let configURL = homeDirectory.appendingPathComponent(".devpurge.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return DevPurgeConfig()
        }
        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            return try decoder.decode(DevPurgeConfig.self, from: data)
        } catch {
            return DevPurgeConfig()
        }
    }

    public func save(to homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        let configURL = homeDirectory.appendingPathComponent(".devpurge.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: configURL, options: .atomic)
    }

    public mutating func addIgnore(category: String, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        if !ignore.contains(category) {
            ignore.append(category)
            try save(to: homeDirectory)
        }
    }

    public mutating func addProjectRoot(_ path: String, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        if !projectScanRoots.contains(standardized) {
            projectScanRoots.append(standardized)
            try save(to: homeDirectory)
        }
    }

    public mutating func removeProjectRoot(_ path: String, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        projectScanRoots.removeAll { $0 == path }
        try save(to: homeDirectory)
    }
}
