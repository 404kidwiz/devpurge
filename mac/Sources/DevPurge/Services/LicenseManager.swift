import Foundation
import Security

public enum LicenseStatus: Equatable, Sendable {
    case unactivated
    case active(licenseKey: String, customerName: String?)
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
            return "Licensed\(name != nil ? " to \(name!)" : "")"
        case .invalid(let reason):
            return "Invalid: \(reason)"
        }
    }
}

public final class LicenseManager: ObservableObject, @unchecked Sendable {
    public static let shared = LicenseManager()

    @Published public private(set) var status: LicenseStatus = .unactivated

    private let keychainService = "com.devpurge.app.license"
    private let keychainAccount = "license_key"

    public init() {
        loadStoredLicense()
    }

    public func loadStoredLicense() {
        if let storedKey = readFromKeychain() {
            // Validate stored key format
            if storedKey.hasPrefix("DEVPURGE-") || storedKey.count >= 16 {
                self.status = .active(licenseKey: storedKey, customerName: nil)
            } else {
                self.status = .unactivated
            }
        } else {
            self.status = .unactivated
        }
    }

    public func activate(key: String, instanceName: String = Host.current().localizedName ?? "Mac") async -> Result<String, Error> {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let err = NSError(domain: "LicenseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please enter a license key."])
            await MainActor.run { self.status = .invalid(reason: err.localizedDescription) }
            return .failure(err)
        }

        // 1. Developer / offline test key support
        if trimmed.hasPrefix("DEVPURGE-DEV-") || trimmed.hasPrefix("TEST-") {
            saveToKeychain(key: trimmed)
            await MainActor.run {
                self.status = .active(licenseKey: trimmed, customerName: "Developer / Tester")
            }
            return .success("Activated successfully (Developer Mode)")
        }

        // 2. Production Lemon Squeezy API Activation
        guard let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate") else {
            let err = NSError(domain: "LicenseManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint"])
            return .failure(err)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload: [String: Any] = [
            "license_key": trimmed,
            "instance_name": instanceName
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "LicenseManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response from license server."])
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if httpResponse.statusCode == 200 && (json["activated"] as? Bool) == true {
                    let meta = json["meta"] as? [String: Any]
                    let customerName = meta?["customer_name"] as? String

                    saveToKeychain(key: trimmed)
                    await MainActor.run {
                        self.status = .active(licenseKey: trimmed, customerName: customerName)
                    }
                    return .success("License activated successfully!")
                } else {
                    let errMsg = (json["error"] as? String) ?? "License key could not be verified."
                    await MainActor.run {
                        self.status = .invalid(reason: errMsg)
                    }
                    return .failure(NSError(domain: "LicenseManager", code: 4, userInfo: [NSLocalizedDescriptionKey: errMsg]))
                }
            } else {
                throw NSError(domain: "LicenseManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Server response format error."])
            }
        } catch {
            await MainActor.run {
                self.status = .invalid(reason: error.localizedDescription)
            }
            return .failure(error)
        }
    }

    public func deactivate() {
        deleteFromKeychain()
        status = .unactivated
    }

    // MARK: - Keychain Helpers

    @discardableResult
    public func saveToKeychain(key: String) -> Bool {
        deleteFromKeychain()
        guard let data = key.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
