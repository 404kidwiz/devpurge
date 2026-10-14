import Foundation

/// Public licensing identifiers. The Lemon Squeezy License API needs no API key:
/// never add a store/API secret to the app.
public struct LicenseConfig: Sendable, Equatable {
    public let storeID: Int
    public let productID: Int
    public let checkoutURL: URL?
    public let apiBase: URL
    public let offlineGraceDays: Int
    public let revalidateAfterHours: Int
    public let freeCleanups: Int
    /// Only honored in DEBUG builds; release builds compile the bypass out entirely.
    public let allowDebugKeys: Bool

    public init(
        storeID: Int,
        productID: Int,
        checkoutURL: URL?,
        apiBase: URL = URL(string: "https://api.lemonsqueezy.com/v1/licenses")!,
        offlineGraceDays: Int = 14,
        revalidateAfterHours: Int = 24,
        freeCleanups: Int = 3,
        allowDebugKeys: Bool = false
    ) {
        self.storeID = storeID
        self.productID = productID
        self.checkoutURL = checkoutURL
        self.apiBase = apiBase
        self.offlineGraceDays = offlineGraceDays
        self.revalidateAfterHours = revalidateAfterHours
        self.freeCleanups = freeCleanups
        self.allowDebugKeys = allowDebugKeys
    }

    /// Activation is refused until real IDs are set, so keys from other products are never accepted.
    public var isConfigured: Bool { storeID > 0 && productID > 0 }

    public static let production: LicenseConfig = {
        #if DEBUG
        let debugKeys = true
        #else
        let debugKeys = false
        #endif
        return LicenseConfig(
            storeID: 0,    // TODO: Lemon Squeezy store ID (public)
            productID: 0,  // TODO: Lemon Squeezy product ID (public)
            checkoutURL: URL(string: "https://github.com/404kidwiz/devpurge#devpurge-for-mac"), // TODO: checkout URL
            allowDebugKeys: debugKeys
        )
    }()
}
