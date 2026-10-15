import Foundation

public struct DevPurgeConfig: Codable, Sendable {
    public var automatedSweep: Bool
    public var rescueMode: Bool
    public var ignore: [String]
    public var intervalDays: Int

    public init(
        automatedSweep: Bool = false,
        rescueMode: Bool = false,
        ignore: [String] = [],
        intervalDays: Int = 7
    ) {
        self.automatedSweep = automatedSweep
        self.rescueMode = rescueMode
        self.ignore = ignore
        self.intervalDays = intervalDays
    }

    enum CodingKeys: String, CodingKey {
        case automatedSweep = "automated_sweep"
        case rescueMode = "rescue_mode"
        case ignore
        case intervalDays = "interval_days"
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
}
