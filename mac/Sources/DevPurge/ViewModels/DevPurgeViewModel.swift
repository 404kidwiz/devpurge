import SwiftUI
import Combine

public enum FilterOption: String, CaseIterable, Identifiable {
    case all = "All locations"
    case eligible = "Eligible"
    case kept = "Kept"

    public var id: String { rawValue }
}

@MainActor
public final class DevPurgeViewModel: ObservableObject {
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var statusMessage: String = "Ready when you are. A scan won’t change any files."
    @Published public var isStatusError: Bool = false

    @Published public var diskSpace: DiskSpace = DiskMonitor.getDiskSpace()
    @Published public var targets: [Target] = []
    @Published public var selectedTargetIDs: Set<String> = []
    @Published public var filter: FilterOption = .all
    @Published public var searchQuery: String = ""
    @Published public var rescueMode: Bool = false

    @Published public var isReviewPresented: Bool = false
    @Published public var isLicenseSheetPresented: Bool = false
    @Published public var cleanupResults: [CleanupResult] = []
    @Published public var scannedAt: Date? = nil
    @Published public var apfsReport: APFSSnapshotReport = APFSSnapshotReport(snapshotCount: 0, snapshotNames: [])

    public let licenseManager = LicenseManager.shared
    public var config: DevPurgeConfig = DevPurgeConfig.load()
    private let scanner: TargetScanner
    private let executor: SafetyExecutor

    public init(
        scanner: TargetScanner = TargetScanner(),
        executor: SafetyExecutor? = nil
    ) {
        self.scanner = scanner
        self.executor = executor ?? SafetyExecutor(scanner: scanner)
        self.rescueMode = config.rescueMode

        if BetaExpiryGuard.isExpired {
            self.statusMessage = BetaExpiryGuard.expiredNotice
            self.isStatusError = true
        }
    }

    public var filteredTargets: [Target] {
        var list = targets

        switch filter {
        case .all:
            break
        case .eligible:
            list = list.filter { $0.status == .eligible }
        case .kept:
            list = list.filter { $0.status != .eligible }
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.path.lowercased().contains(query) ||
                $0.category.lowercased().contains(query) ||
                $0.displayName.lowercased().contains(query)
            }
        }

        return list
    }

    public var totalScannedStoredBytes: Int64 {
        targets.compactMap { $0.sizeBytes }.reduce(0, +)
    }

    public var totalSelectedBytes: Int64 {
        targets
            .filter { selectedTargetIDs.contains($0.id) }
            .compactMap { $0.sizeBytes }
            .reduce(0, +)
    }

    public var eligibleCount: Int {
        targets.filter { $0.status == .eligible }.count
    }

    public var selectedTargets: [Target] {
        targets.filter { selectedTargetIDs.contains($0.id) }
    }

    public func scan() {
        guard !isScanning else { return }
        isScanning = true
        statusMessage = "Scanning storage locations and measuring sizes..."
        isStatusError = false
        selectedTargetIDs = []
        cleanupResults = []
        targets = []

        Task {
            config = DevPurgeConfig.load()
            let snapshots = APFSSnapshotInspector.checkLocalSnapshots()
            self.apfsReport = snapshots

            for await target in scanner.scanStream(config: config) {
                self.targets.append(target)
            }

            let updatedDisk = DiskMonitor.getDiskSpace()
            self.diskSpace = updatedDisk
            self.scannedAt = Date()
            self.isScanning = false

            let count = targets.count
            let eligible = targets.filter { $0.status == .eligible }.count
            self.statusMessage = "Scan complete. \(count) locations inspected; \(eligible) eligible for cleanup."
        }
    }

    public func ignoreCategory(_ category: String) {
        do {
            try config.addIgnore(category: category)
            for i in 0..<targets.count where targets[i].category == category {
                targets[i].status = .ignored
                targets[i].reason = "Ignored by DevPurge configuration"
                selectedTargetIDs.remove(targets[i].id)
            }
            statusMessage = "Group '\(category)' added to ignore list in ~/.devpurge.json"
        } catch {
            statusMessage = "Failed to update configuration: \(error.localizedDescription)"
            isStatusError = true
        }
    }

    public func toggleSelection(for target: Target) {
        guard target.status == .eligible else { return }
        if selectedTargetIDs.contains(target.id) {
            selectedTargetIDs.remove(target.id)
        } else {
            selectedTargetIDs.insert(target.id)
        }
    }

    public func selectAllEligible() {
        let eligibleIDs = targets.filter { $0.status == .eligible }.map { $0.id }
        selectedTargetIDs.formUnion(eligibleIDs)
    }

    public func deselectAll() {
        selectedTargetIDs.removeAll()
    }

    public func prepareReview() {
        guard !BetaExpiryGuard.isExpired else {
            statusMessage = BetaExpiryGuard.expiredNotice
            isStatusError = true
            return
        }
        guard !selectedTargetIDs.isEmpty else { return }
        isReviewPresented = true
    }

    public func executeCleanup() {
        guard !BetaExpiryGuard.isExpired else {
            statusMessage = BetaExpiryGuard.expiredNotice
            isStatusError = true
            return
        }
        guard !isCleaning else { return }
        let toClean = selectedTargets
        guard !toClean.isEmpty else { return }

        isCleaning = true
        isReviewPresented = false
        statusMessage = "Executing cleanup with pre-flight safety checks..."

        Task {
            let results = executor.executePlan(targets: toClean, rescue: rescueMode, config: config)
            self.cleanupResults = results
            self.targets.removeAll()
            self.selectedTargetIDs.removeAll()
            self.diskSpace = DiskMonitor.getDiskSpace()
            self.isCleaning = false

            let successful = results.filter { $0.isSuccess }.count
            self.statusMessage = "Cleanup finished. \(successful) of \(results.count) items processed."
        }
    }
}
