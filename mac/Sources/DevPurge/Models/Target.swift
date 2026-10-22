import Foundation

public enum TargetStatus: String, Codable, Sendable {
    case eligible = "eligible"
    case inUse = "in-use"
    case review = "review"
    case ignored = "ignored"

    public var badgeLabel: String {
        switch self {
        case .eligible: return "Eligible"
        case .inUse: return "In use"
        case .review: return "Review"
        case .ignored: return "Ignored"
        }
    }
}

public struct Target: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let path: String
    public let category: String
    public var status: TargetStatus
    public var reason: String
    public var command: [String]
    public var sizeBytes: Int64?
    public var sizeError: String

    public init(
        id: String = UUID().uuidString,
        path: String,
        category: String,
        status: TargetStatus = .review,
        reason: String = "No supported safe cleanup action",
        command: [String] = [],
        sizeBytes: Int64? = nil,
        sizeError: String = ""
    ) {
        self.id = id
        self.path = path
        self.category = category
        self.status = status
        self.reason = reason
        self.command = command
        self.sizeBytes = sizeBytes
        self.sizeError = sizeError
    }

    public var displayName: String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    public var formattedSize: String {
        guard let size = sizeBytes else { return "—" }
        return ByteFormat.string(size)
    }
}
