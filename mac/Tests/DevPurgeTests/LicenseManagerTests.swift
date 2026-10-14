import XCTest
@testable import DevPurge

private final class MockHTTP: LicenseHTTPClient, @unchecked Sendable {
    enum Reply { case json(Int, String), fail }
    private let lock = NSLock()
    private var replies: [String: Reply]
    private(set) var calls: [(endpoint: String, fields: [String: String])] = []

    init(_ replies: [String: Reply]) { self.replies = replies }

    func postForm(_ url: URL, fields: [String: String]) async throws -> (Data, Int) {
        let reply: Reply? = lock.withLock {
            calls.append((url.lastPathComponent, fields))
            return replies[url.lastPathComponent]
        }
        switch reply {
        case .json(let code, let body)?: return (Data(body.utf8), code)
        case .fail?, nil: throw URLError(.notConnectedToInternet)
        }
    }
}

final class LicenseManagerTests: XCTestCase {
    private let iso = ISO8601DateFormatter()
    private let config = LicenseConfig(storeID: 11, productID: 22, checkoutURL: nil, allowDebugKeys: false)
    private let okActivate = #"{"activated":true,"instance":{"id":"inst-1"},"meta":{"store_id":11,"product_id":22,"customer_name":"Ada"}}"#

    private func licensedStore(daysAgo: Double) -> InMemoryLicenseStore {
        InMemoryLicenseStore([
            .licenseKey: "KEY-123",
            .instanceID: "inst-1",
            .lastValidated: iso.string(from: Date().addingTimeInterval(-daysAgo * 86_400))
        ])
    }

    @MainActor
    func testDebugPrefixesAreRejectedWhenDebugKeysDisabled() async {
        let http = MockHTTP(["activate": .json(404, #"{"activated":false,"error":"license_key not found."}"#)])
        let store = InMemoryLicenseStore()
        let manager = LicenseManager(config: config, store: store, http: http)
        for key in ["DEVPURGE-DEV-UNLIMITED", "TEST-1234"] {
            let result = await manager.activate(key: key, instanceName: "Test Mac")
            if case .success = result { XCTFail("\(key) must not activate") }
        }
        XCTAssertFalse(manager.status.isActive)
        XCTAssertNil(store.read(.licenseKey))
        XCTAssertEqual(http.calls.count, 2, "keys must go to the server, not a local bypass")
    }

    func testProductionConfigHasNoSecretsAndRefusesUnconfiguredIDs() {
        #if !DEBUG
        XCTAssertFalse(LicenseConfig.production.allowDebugKeys)
        #endif
        XCTAssertEqual(LicenseConfig.production.apiBase.absoluteString, "https://api.lemonsqueezy.com/v1/licenses")
    }

    @MainActor
    func testActivateUsesFormFieldsAndStoresInstance() async {
        let http = MockHTTP(["activate": .json(200, okActivate)])
        let store = InMemoryLicenseStore()
        let manager = LicenseManager(config: config, store: store, http: http)
        let result = await manager.activate(key: " KEY-123 ", instanceName: "Test Mac")
        guard case .success = result else { return XCTFail("expected success, got \(result)") }
        XCTAssertEqual(manager.status, .active(licenseKey: "KEY-123", customerName: "Ada"))
        XCTAssertEqual(store.read(.instanceID), "inst-1")
        XCTAssertEqual(http.calls.first?.endpoint, "activate")
        XCTAssertEqual(http.calls.first?.fields, ["license_key": "KEY-123", "instance_name": "Test Mac"])
        XCTAssertTrue(manager.canClean)
    }

    @MainActor
    func testWrongProductIsRejectedAndSlotReleased() async {
        let other = #"{"activated":true,"instance":{"id":"inst-9"},"meta":{"store_id":11,"product_id":999}}"#
        let http = MockHTTP(["activate": .json(200, other), "deactivate": .json(200, #"{"deactivated":true}"#)])
        let store = InMemoryLicenseStore()
        let manager = LicenseManager(config: config, store: store, http: http)
        let result = await manager.activate(key: "KEY-OTHER", instanceName: "Mac")
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? LicenseError, .wrongProduct)
        XCTAssertNil(store.read(.licenseKey))
        XCTAssertEqual(http.calls.map(\.endpoint), ["activate", "deactivate"])
    }

    @MainActor
    func testUnconfiguredBuildRefusesActivationWithoutNetwork() async {
        let http = MockHTTP([:])
        let manager = LicenseManager(config: LicenseConfig(storeID: 0, productID: 0, checkoutURL: nil),
                                     store: InMemoryLicenseStore(), http: http)
        let result = await manager.activate(key: "KEY-123", instanceName: "Mac")
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? LicenseError, .notConfigured)
        XCTAssertTrue(http.calls.isEmpty)
    }

    @MainActor
    func testNetworkErrorWithinGraceKeepsLicense() async {
        let store = licensedStore(daysAgo: 3)
        let manager = LicenseManager(config: config, store: store, http: MockHTTP(["validate": .fail]))
        let status = await manager.validate(force: true)
        XCTAssertTrue(status.isActive)
        XCTAssertEqual(store.read(.licenseKey), "KEY-123")
    }

    @MainActor
    func testServerErrorNeverRevokes() async {
        let store = licensedStore(daysAgo: 2)
        let manager = LicenseManager(config: config, store: store,
                                     http: MockHTTP(["validate": .json(503, "<html>down</html>")]))
        let refreshedStatus = await manager.validate(force: true)
        XCTAssertTrue(refreshedStatus.isActive)
        XCTAssertEqual(store.read(.licenseKey), "KEY-123")
    }

    @MainActor
    func testOfflineBeyondGraceKeepsKeyButNeedsRevalidation() async {
        let store = licensedStore(daysAgo: 20)
        store.write(.trialUsed, "3")
        let manager = LicenseManager(config: config, store: store, http: MockHTTP(["validate": .fail]))
        let status = await manager.validate(force: true)
        XCTAssertEqual(status, .needsRevalidation(licenseKey: "KEY-123"))
        XCTAssertEqual(store.read(.licenseKey), "KEY-123", "network errors must never delete the key")
        XCTAssertFalse(manager.canClean)
    }

    @MainActor
    func testExplicitInvalidResponseRevokes() async {
        let store = licensedStore(daysAgo: 2)
        let body = #"{"valid":false,"error":"This license key is disabled.","license_key":{"status":"disabled"}}"#
        let manager = LicenseManager(config: config, store: store, http: MockHTTP(["validate": .json(200, body)]))
        let status = await manager.validate(force: true)
        XCTAssertEqual(status, .invalid(reason: "This license key is disabled."))
        XCTAssertNil(store.read(.licenseKey))
    }

    @MainActor
    func testSuccessfulValidateRefreshesTimestamp() async {
        let store = licensedStore(daysAgo: 10)
        let body = #"{"valid":true,"license_key":{"status":"active"},"meta":{"store_id":11,"product_id":22}}"#
        let manager = LicenseManager(config: config, store: store, http: MockHTTP(["validate": .json(200, body)]))
        let refreshedStatus = await manager.validate(force: true)
        XCTAssertTrue(refreshedStatus.isActive)
        let refreshed = iso.date(from: store.read(.lastValidated) ?? "")
        XCTAssertNotNil(refreshed)
        XCTAssertLessThan(Date().timeIntervalSince(refreshed!), 60)
    }

    @MainActor
    func testDeactivateClearsLocallyEvenWhenOffline() async {
        let store = licensedStore(daysAgo: 1)
        let manager = LicenseManager(config: config, store: store, http: MockHTTP(["deactivate": .fail]))
        let message = await manager.deactivate()
        XCTAssertTrue(message.contains("couldn't confirm"))
        XCTAssertEqual(manager.status, .unactivated)
        XCTAssertNil(store.read(.licenseKey))
    }

    func testLegacyKeyWithoutInstanceRequiresActivation() {
        let store = InMemoryLicenseStore([.licenseKey: "OLD-STYLE-KEY-1234567"])
        let manager = LicenseManager(config: config, store: store, http: MockHTTP([:]))
        XCTAssertEqual(manager.status, .unactivated)
        XCTAssertNil(store.read(.licenseKey))
    }

    func testTrialAllowsThreeCleanupsAndPersists() {
        let store = InMemoryLicenseStore()
        let manager = LicenseManager(config: config, store: store, http: MockHTTP([:]))
        XCTAssertTrue(manager.canClean)
        XCTAssertEqual(manager.badgeText, "Trial · 3 free cleanups left")
        for _ in 0..<3 { manager.recordTrialCleanup() }
        XCTAssertFalse(manager.canClean)
        XCTAssertEqual(LicenseManager(config: config, store: store, http: MockHTTP([:])).trialUsed, 3)
        XCTAssertFalse(TrialGuard(freeCleanups: 3, used: 3).canClean(licensed: false))
        XCTAssertTrue(TrialGuard(freeCleanups: 3, used: 3).canClean(licensed: true))
    }
}
