import Foundation
import Security

public enum LicenseField: String, CaseIterable, Sendable {
    case licenseKey = "license_key"
    case instanceID = "instance_id"
    case lastValidated = "last_validated"
    case customerName = "customer_name"
    case trialUsed = "trial_cleanups_used"
}

public protocol LicenseStore: AnyObject, Sendable {
    func read(_ field: LicenseField) -> String?
    func write(_ field: LicenseField, _ value: String?)
}

/// Stores license state in the login Keychain.
public final class KeychainLicenseStore: LicenseStore, @unchecked Sendable {
    private let service: String

    public init(service: String = "com.devpurge.app.license") {
        self.service = service
    }

    public func read(_ field: LicenseField) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: field.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func write(_ field: LicenseField, _ value: String?) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: field.rawValue
        ]
        SecItemDelete(base as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// In-memory store for tests and previews.
public final class InMemoryLicenseStore: LicenseStore, @unchecked Sendable {
    private var values: [LicenseField: String] = [:]
    private let lock = NSLock()

    public init(_ initial: [LicenseField: String] = [:]) {
        values = initial
    }

    public func read(_ field: LicenseField) -> String? {
        lock.lock(); defer { lock.unlock() }
        return values[field]
    }

    public func write(_ field: LicenseField, _ value: String?) {
        lock.lock(); defer { lock.unlock() }
        values[field] = value
    }
}

public protocol LicenseHTTPClient: Sendable {
    /// Returns the body and HTTP status code. Throws only for transport failures.
    func postForm(_ url: URL, fields: [String: String]) async throws -> (Data, Int)
}

public struct URLSessionLicenseClient: LicenseHTTPClient {
    public init() {}

    public func postForm(_ url: URL, fields: [String: String]) async throws -> (Data, Int) {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(fields).data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    static func formEncode(_ fields: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields.sorted { $0.key < $1.key }.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&")
    }
}
