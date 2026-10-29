import SwiftUI
import AppKit
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
    @Published public var pruningTargetID: String? = nil
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
    /// Stored size of the items the last cleanup handled successfully.
    @Published public var lastCleanupStoredBytes: Int64 = 0
    /// Free-space change measured on the volume around the last cleanup.
    @Published public var lastCleanupMeasuredBytes: Int64 = 0
    @Published public var lastCleanupUsedTrash: Bool = false
    /// Names of scanned locations the last cleanup left alone.
    @Published public var lastCleanupKept: [String] = []
    @Published public var scannedAt: Date? = nil
    @Published public var apfsReport: APFSSnapshotReport = APFSSnapshotReport(snapshotCount: 0, snapshotNames: [])
    @Published public var config: DevPurgeConfig = DevPurgeConfig.load()

    public let licenseManager = LicenseManager.shared
    private let scanner: TargetScanner
    private let executor: SafetyExecutor

    public init(
        scanner: TargetScanner = TargetScanner(),
        executor: SafetyExecutor? = nil
    ) {
        self.scanner = scanner
        self.executor = executor ?? SafetyExecutor(scanner: scanner)
        self.rescueMode = config.rescueMode

        let license = licenseManager
        Task { await license.validate() }
    }

    public var isLowDiskSpace: Bool {
        let thresholdGB = config.lowDiskAlertThresholdGB
        guard thresholdGB > 0, diskSpace.free > 0 else { return false }
        return diskSpace.free < Int64(thresholdGB) * 1_000_000_000
    }

    public var lowDiskWarningText: String? {
        guard isLowDiskSpace else { return nil }
        return "Low disk space: \(diskSpace.formattedFree) available (below \(config.lowDiskAlertThresholdGB) GB alert threshold)."
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
                $0.displayName.lowercased().contains(query) ||
                $0.friendlyTitle.lowercased().contains(query)
            }
        }

        return list.sorted { a, b in
            let rankA = Self.statusSortRank(a.status)
            let rankB = Self.statusSortRank(b.status)
            if rankA != rankB { return rankA < rankB }
            let sizeA = a.sizeBytes ?? -1
            let sizeB = b.sizeBytes ?? -1
            if sizeA != sizeB { return sizeA > sizeB }
            return a.friendlyTitle.localizedStandardCompare(b.friendlyTitle) == .orderedAscending
        }
    }

    private static func statusSortRank(_ status: TargetStatus) -> Int {
        switch status {
        case .eligible: return 0
        case .inUse: return 1
        case .review: return 2
        case .ignored: return 3
        }
    }

    public var totalScannedStoredBytes: Int64 {
        targets.compactMap { $0.sizeBytes }.reduce(0, +)
    }

    public var totalEligibleBytes: Int64 {
        targets
            .filter { $0.status == .eligible }
            .compactMap { $0.sizeBytes }
            .reduce(0, +)
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

    public func scan(autoSelectEligible: Bool = false) {
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

            if autoSelectEligible {
                self.selectAllEligible()
            }

            let count = targets.count
            let eligible = targets.filter { $0.status == .eligible }.count
            self.statusMessage = autoSelectEligible && eligible > 0
                ? "Scan complete. \(eligible) safe locations (\(ByteFormat.string(totalSelectedBytes))) selected for review."
                : "Scan complete. \(count) locations inspected; \(eligible) eligible for cleanup."
        }
    }

    public func scanAndSelectSafe() {
        scan(autoSelectEligible: true)
    }

    public func chooseProjectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Workspace Folder to Scan for Stale Project Caches"
        panel.message = "DevPurge will scan up to 4 levels deep for node_modules, .venv, and Cargo target folders."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            addProjectRoot(url.path)
        }
    }

    public func addProjectRoot(_ path: String) {
        do {
            try config.addProjectRoot(path, homeDirectory: scanner.homeDirectory)
            isStatusError = false
            let name = URL(fileURLWithPath: path).lastPathComponent
            statusMessage = "Added project folder '\(name)' to scan roots."
            scan()
        } catch {
            isStatusError = true
            statusMessage = "Could not save project folder: \(error.localizedDescription)"
        }
    }

    public func removeProjectRoot(_ path: String) {
        do {
            try config.removeProjectRoot(path, homeDirectory: scanner.homeDirectory)
            targets.removeAll { $0.category == "projects" && $0.path.hasPrefix(path + "/") }
            isStatusError = false
            let name = URL(fileURLWithPath: path).lastPathComponent
            statusMessage = "Removed project folder '\(name)' from scan roots."
        } catch {
            isStatusError = true
            statusMessage = "Could not update configuration: \(error.localizedDescription)"
        }
    }

    public func updateStaleProjectDays(_ days: Int) {
        config.staleProjectDays = max(1, days)
        try? config.save(to: scanner.homeDirectory)
    }

    public func updateLowDiskThresholdGB(_ gb: Int) {
        config.lowDiskAlertThresholdGB = max(0, gb)
        try? config.save(to: scanner.homeDirectory)
    }

    /// Runs a safe native package-manager/tooling prune (`uv cache prune`, `npm cache verify`, etc.)
    /// after verifying the location is not actively in use.
    public func runNativeToolPrune(for target: Target) {
        guard let spec = target.nativePruneSpec else { return }
        guard !isScanning && !isCleaning && pruningTargetID == nil else { return }

        pruningTargetID = target.id
        isStatusError = false
        statusMessage = "Running \(spec.command.joined(separator: " ")) on \(target.friendlyTitle)..."

        let beforeBytes = target.sizeBytes ?? 0
        let targetID = target.id
        let targetPath = target.path
        let targetTitle = target.friendlyTitle
        let homeDir = scanner.homeDirectory
        let procInspector = scanner.processInspector

        Task {
            let outcome = await Task.detached(priority: .userInitiated) { () -> (exitCode: Int32, reason: String?, afterBytes: Int64?) in
                procInspector.refresh()
                if let active = procInspector.active(path: targetPath, bundle: nil) {
                    return (-2, active.reason, nil)
                }
                let res = ProcessInspector.runCommand(spec.command, currentDirectoryURL: homeDir, timeout: 60)
                let measured = TargetScanner.measure(path: targetPath)
                return (res.exitCode, nil, measured.sizeBytes)
            }.value

            self.pruningTargetID = nil
            self.diskSpace = DiskMonitor.getDiskSpace()

            if outcome.exitCode == -2 {
                if let idx = self.targets.firstIndex(where: { $0.id == targetID }) {
                    self.targets[idx].status = .inUse
                    self.targets[idx].reason = outcome.reason ?? "Open files or a mounted disk image"
                }
                self.isStatusError = true
                self.statusMessage = "Skipped \(targetTitle): \(outcome.reason ?? "in use")."
                return
            }

            if outcome.exitCode == 0 {
                if let idx = self.targets.firstIndex(where: { $0.id == targetID }) {
                    self.targets[idx].sizeBytes = outcome.afterBytes
                }
                let afterBytes = outcome.afterBytes ?? beforeBytes
                let delta = max(0, beforeBytes - afterBytes)
                self.statusMessage = delta > 0
                    ? "Pruned \(targetTitle) — reclaimed \(ByteFormat.string(delta))."
                    : "Pruned \(targetTitle) — cache verified (\(ByteFormat.string(afterBytes)) retained)."
            } else {
                self.isStatusError = true
                self.statusMessage = "Native prune could not run for \(targetTitle) (exit \(outcome.exitCode))."
            }
        }
    }

    public func copyScanReportToClipboard() {
        guard !targets.isEmpty else {
            statusMessage = "Run a scan first to copy a storage report."
            return
        }
        var lines: [String] = [
            "# DevPurge Storage Report",
            "- Available on disk: \(diskSpace.formattedFree) of \(diskSpace.formattedTotal)",
            "- Stored in scanned locations: \(ByteFormat.string(totalScannedStoredBytes))",
            "- Eligible safe locations: \(eligibleCount) (\(ByteFormat.string(totalEligibleBytes)))",
            ""
        ]
        for t in filteredTargets {
            lines.append("- [\(t.status.badgeLabel.uppercased())] \(t.friendlyTitle) — \(t.formattedSize) (`\(t.path)`) · \(t.reason)")
        }
        let report = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        isStatusError = false
        statusMessage = "Copied storage report (\(filteredTargets.count) locations) to clipboard."
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
        guard licenseManager.canClean else {
            statusMessage = TrialGuard.lockedNotice
            isStatusError = true
            isLicenseSheetPresented = true
            return
        }
        guard !selectedTargetIDs.isEmpty else { return }
        isReviewPresented = true
    }

    public func executeCleanup() {
        guard licenseManager.canClean else {
            statusMessage = TrialGuard.lockedNotice
            isStatusError = true
            return
        }
        guard !isCleaning else { return }
        let toClean = selectedTargets
        guard !toClean.isEmpty else { return }

        isCleaning = true
        isReviewPresented = false
        statusMessage = "Executing cleanup with pre-flight safety checks..."

        let freeBefore = diskSpace.free
        let usedTrash = rescueMode
        let kept = targets.filter { !selectedTargetIDs.contains($0.id) }.map(\.friendlyTitle)

        Task {
            let results = executor.executePlan(targets: toClean, rescue: usedTrash, config: config)
            self.cleanupResults = results
            let okPaths = Set(results.filter(\.isSuccess).map(\.path))
            self.lastCleanupStoredBytes = toClean.filter { okPaths.contains($0.path) }.compactMap(\.sizeBytes).reduce(0, +)
            self.lastCleanupUsedTrash = usedTrash
            self.lastCleanupKept = kept
            self.targets.removeAll()
            self.selectedTargetIDs.removeAll()
            self.diskSpace = DiskMonitor.getDiskSpace()
            self.lastCleanupMeasuredBytes = max(0, self.diskSpace.free - freeBefore)
            self.isCleaning = false

            let successful = results.filter { $0.isSuccess }.count
            if successful > 0 { self.licenseManager.recordTrialCleanup() }
            self.statusMessage = "Cleanup finished. \(successful) of \(results.count) items processed."
        }
    }
}
