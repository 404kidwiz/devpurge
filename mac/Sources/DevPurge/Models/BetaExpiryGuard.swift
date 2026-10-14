import Foundation

public struct BetaExpiryGuard: Sendable {
    // Release/build anchor: September 21, 2026
    // Default trial window: 45 days
    public static let buildDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 21
        return Calendar.current.date(from: components) ?? Date()
    }()

    public static let trialDays: Int = 45

    public static var expiryDate: Date {
        Calendar.current.date(byAdding: .day, value: trialDays, to: buildDate) ?? buildDate
    }

    public static var isExpired: Bool {
        Date() > expiryDate
    }

    public static var daysRemaining: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate)
        return max(0, diff.day ?? 0)
    }

    public static var badgeText: String {
        if isExpired {
            return "Beta Expired"
        } else {
            let days = daysRemaining
            return "Private Beta · \(days) day\(days == 1 ? "" : "s") left"
        }
    }

    public static var expiredNotice: String {
        "This beta build of DevPurge expired on \(expiryDate.formatted(date: .abbreviated, time: .omitted)). Please obtain the latest release."
    }
}
