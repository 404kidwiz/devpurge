import Foundation

/// Scanning is always free; cleanup is licensed after a small number of free cleanups.
public struct TrialGuard: Sendable, Equatable {
    public let freeCleanups: Int
    public let used: Int

    public init(freeCleanups: Int, used: Int) {
        self.freeCleanups = freeCleanups
        self.used = max(0, used)
    }

    public var remaining: Int { max(0, freeCleanups - used) }
    public var isExhausted: Bool { remaining == 0 }

    public func canClean(licensed: Bool) -> Bool { licensed || !isExhausted }

    public var badgeText: String {
        if isExhausted { return "Trial used · scanning stays free" }
        return "Trial · \(remaining) free cleanup\(remaining == 1 ? "" : "s") left"
    }

    public static let lockedNotice = "Your free cleanups are used. Scanning stays free; activate a license to clean."
}
