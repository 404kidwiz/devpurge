import Foundation

public enum LicenseStatus: Equatable, Sendable {
    case unactivated
    case active(licenseKey: String, customerName: String?)
    /// Offline longer than the grace period. The key is kept; cleanup resumes after one successful check.
    case needsRevalidation(licenseKey: String)
    case invalid(reason: String)

    public var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    public var displayLabel: String {
        switch self {
        case .unactivated:
            return "Unregistered / Trial"
        case .active(_, let name):
            return "Licensed\(name.map { " to \($0)" } ?? "")"
        case .needsRevalidation:
            return "Reconnect to verify license"
        case .invalid(let reason):
            return "Invalid: \(reason)"
        }
    }
}

public enum LicenseError: LocalizedError, Equatable {
    case emptyKey
    case notConfigured
    case network(String)
    case rejected(String)
    case wrongProduct

    public var errorDescription: String? {
        switch self {
        case .emptyKey: return "Please enter a license key."
        case .notConfigured: return "This build isn't configured for license activation yet."
        case .network(let detail): return "Couldn't reach the license server. Your license wasn't changed. (\(detail))"
        case .rejected(let message): return message
        case .wrongProduct: return "This license key belongs to a different product."
        }
    }
}

/// Lemon Squeezy License API client (https://docs.lemonsqueezy.com/api/license-api).
/// Uses only the customer's license key: no API key ships in the app.
public final class LicenseManager: ObservableObject, @unchecked Sendable {
    public static let shared = LicenseManager()

    @Published public private(set) var status: LicenseStatus = .unactivated
    @Published public private(set) var trialUsed: Int = 0

    public let config: LicenseConfig
    private let store: LicenseStore
    private let http: LicenseHTTPClient
    private let now: @Sendable () -> Date
    nonisolated(unsafe) private static let iso = ISO8601DateFormatter()

    public init(
        config: LicenseConfig = .production,
        store: LicenseStore = KeychainLicenseStore(),
        http: LicenseHTTPClient = URLSessionLicenseClient(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.config = config
        self.store = store
        self.http = http
        self.now = now
        loadStoredLicense()
    }

    // MARK: - Entitlement

    public var trial: TrialGuard { TrialGuard(freeCleanups: config.freeCleanups, used: trialUsed) }
    public var canClean: Bool { trial.canClean(licensed: status.isActive) }

    public var badgeText: String {
        switch status {
        case .active: return "Licensed"
        case .needsRevalidation: return "Reconnect to verify license"
        default: return trial.badgeText
        }
    }

    /// Counts one free cleanup when unlicensed. Scans never count.
    public func recordTrialCleanup() {
        guard !status.isActive else { return }
        trialUsed += 1
        store.write(.trialUsed, String(trialUsed))
    }

    // MARK: - Stored state

    public func loadStoredLicense() {
        trialUsed = Int(store.read(.trialUsed) ?? "") ?? 0
        guard let key = store.read(.licenseKey), !key.isEmpty else {
            status = .unactivated
            return
        }
        #if DEBUG
        if config.allowDebugKeys && Self.isDebugKey(key) {
            status = .active(licenseKey: key, customerName: "Developer (debug build)")
            return
        }
        #endif
        guard store.read(.instanceID) != nil else {
            // Legacy or incomplete activation: require a fresh activation.
            clearLicense()
            status = .unactivated
            return
        }
        applyOfflineGrace(key: key)
    }

    private var lastValidated: Date? {
        store.read(.lastValidated).flatMap { Self.iso.date(from: $0) }
    }

    private func applyOfflineGrace(key: String) {
        if let last = lastValidated,
           now().timeIntervalSince(last) <= Double(config.offlineGraceDays) * 86_400 {
            status = .active(licenseKey: key, customerName: store.read(.customerName))
        } else {
            status = .needsRevalidation(licenseKey: key)
        }
    }

    private func clearLicense() {
        for field in [LicenseField.licenseKey, .instanceID, .lastValidated, .customerName] {
            store.write(field, nil)
        }
    }

    #if DEBUG
    private static func isDebugKey(_ key: String) -> Bool {
        key.hasPrefix("DEVPURGE-DEV-") || key.hasPrefix("TEST-")
    }
    #endif

    private func endpoint(_ name: String) -> URL { config.apiBase.appendingPathComponent(name) }

    private static func parse(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func matchesProduct(_ meta: [String: Any]?) -> Bool {
        guard let meta else { return false }
        return (meta["store_id"] as? Int) == config.storeID && (meta["product_id"] as? Int) == config.productID
    }

    // MARK: - API

    @MainActor
    public func activate(key: String, instanceName: String = Host.current().localizedName ?? "Mac") async -> Result<String, Error> {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(LicenseError.emptyKey) }

        #if DEBUG
        if config.allowDebugKeys && Self.isDebugKey(trimmed) {
            store.write(.licenseKey, trimmed)
            store.write(.instanceID, "debug")
            store.write(.lastValidated, Self.iso.string(from: now()))
            status = .active(licenseKey: trimmed, customerName: "Developer (debug build)")
            return .success("Activated (debug build only)")
        }
        #endif

        guard config.isConfigured else { return .failure(LicenseError.notConfigured) }

        let data: Data
        let code: Int
        do {
            (data, code) = try await http.postForm(endpoint("activate"), fields: [
                "license_key": trimmed,
                "instance_name": instanceName
            ])
        } catch {
            return .failure(LicenseError.network(error.localizedDescription))
        }
        guard code != 0, code < 500, code != 429, let json = Self.parse(data) else {
            return .failure(LicenseError.network("HTTP \(code)"))
        }

        let instanceID = (json["instance"] as? [String: Any])?["id"] as? String
        guard code == 200, (json["activated"] as? Bool) == true, let instanceID else {
            let message = (json["error"] as? String) ?? "License key could not be activated."
            if !status.isActive { status = .invalid(reason: message) }
            return .failure(LicenseError.rejected(message))
        }

        let meta = json["meta"] as? [String: Any]
        guard matchesProduct(meta) else {
            // Release the slot we just used on the other product's key.
            _ = try? await http.postForm(endpoint("deactivate"), fields: [
                "license_key": trimmed,
                "instance_id": instanceID
            ])
            if !status.isActive { status = .invalid(reason: LicenseError.wrongProduct.localizedDescription) }
            return .failure(LicenseError.wrongProduct)
        }

        let customer = meta?["customer_name"] as? String
        store.write(.licenseKey, trimmed)
        store.write(.instanceID, instanceID)
        store.write(.lastValidated, Self.iso.string(from: now()))
        store.write(.customerName, customer)
        status = .active(licenseKey: trimmed, customerName: customer)
        return .success("License activated. Thanks for supporting DevPurge!")
    }

    /// Validates at most once per `revalidateAfterHours` unless forced.
    /// Only an explicit server rejection revokes; network/server errors fall back to offline grace.
    @MainActor
    @discardableResult
    public func validate(force: Bool = false) async -> LicenseStatus {
        guard let key = store.read(.licenseKey), let instanceID = store.read(.instanceID) else { return status }
        #if DEBUG
        if config.allowDebugKeys && Self.isDebugKey(key) { return status }
        #endif
        if !force, status.isActive, let last = lastValidated,
           now().timeIntervalSince(last) < Double(config.revalidateAfterHours) * 3_600 {
            return status
        }
        guard config.isConfigured else {
            applyOfflineGrace(key: key)
            return status
        }

        if case let (data, code)? = try? await http.postForm(endpoint("validate"), fields: [
            "license_key": key,
            "instance_id": instanceID
        ]), code != 0, code < 500, code != 429, let json = Self.parse(data) {
            let keyStatus = (json["license_key"] as? [String: Any])?["status"] as? String
            let valid = (json["valid"] as? Bool) == true
            if code == 200, valid, matchesProduct(json["meta"] as? [String: Any]),
               keyStatus != "disabled", keyStatus != "expired" {
                store.write(.lastValidated, Self.iso.string(from: now()))
                status = .active(licenseKey: key, customerName: store.read(.customerName))
                return status
            }
            // Explicit answer from the license server: revoke.
            let reason = (json["error"] as? String)
                ?? "This license is no longer valid\(keyStatus.map { " (\($0))" } ?? "")."
            clearLicense()
            status = .invalid(reason: reason)
            return status
        }

        // Transport failure, rate limit or server error: never revoke.
        applyOfflineGrace(key: key)
        return status
    }

    /// Frees this Mac's activation slot. Always removes the license locally.
    @MainActor
    public func deactivate() async -> String {
        let key = store.read(.licenseKey)
        let instanceID = store.read(.instanceID)
        var released = false
        if let key, let instanceID, instanceID != "debug", config.isConfigured,
           case let (data, code)? = try? await http.postForm(endpoint("deactivate"), fields: [
               "license_key": key,
               "instance_id": instanceID
           ]), code == 200, (Self.parse(data)?["deactivated"] as? Bool) == true {
            released = true
        }
        clearLicense()
        status = .unactivated
        if released || instanceID == "debug" || key == nil {
            return "License deactivated on this Mac."
        }
        return "Removed from this Mac. The license server couldn't confirm, so this activation may still count toward your device limit."
    }
}
