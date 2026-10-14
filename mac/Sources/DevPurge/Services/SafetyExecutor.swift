import Foundation

public struct CleanupResult: Identifiable, Sendable {
    public let id = UUID()
    public let path: String
    public let status: String
    public let isSuccess: Bool
}

public final class SafetyExecutor: @unchecked Sendable {
    private let scanner: TargetScanner

    public init(scanner: TargetScanner) {
        self.scanner = scanner
    }

    public func executeItem(target: Target, rescue: Bool, config: DevPurgeConfig) -> (status: String, success: Bool) {
        // Re-verify eligibility immediately before execution
        scanner.appRegistry.refresh()
        scanner.processInspector.refresh()

        if config.ignore.contains(target.category) {
            return ("SKIPPED: group is now ignored", false)
        }
        if config.rescueMode && !rescue {
            return ("SKIPPED: rescue mode is enabled in configuration", false)
        }

        var liveTargets: [Target] = []
        switch target.category {
        case "browsers": liveTargets = scanner.collectBrowserTargets()
        case "installers": liveTargets = scanner.collectInstallerTargets()
        case "oldstores": liveTargets = scanner.collectOldStoreTargets()
        default: liveTargets = scanner.collectReviewTargets()
        }

        guard let current = liveTargets.first(where: { $0.path == target.path }) else {
            return ("SKIPPED: target changed or disappeared", false)
        }
        guard current.status == .eligible else {
            return ("SKIPPED: \(current.reason)", false)
        }

        if !current.command.isEmpty {
            if rescue {
                return ("SKIPPED: native pruning cannot be rescued to Trash", false)
            }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = current.command
            proc.currentDirectoryURL = scanner.homeDirectory
            do {
                try proc.run()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 {
                    return ("PRUNED", true)
                } else {
                    return ("FAILED: native command exited with code \(proc.terminationStatus)", false)
                }
            } catch {
                return ("FAILED: \(error.localizedDescription)", false)
            }
        }

        let url = URL(fileURLWithPath: current.path)
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return ("SKIPPED: file no longer exists", false)
        }

        if rescue {
            do {
                var trashURL: NSURL?
                try fm.trashItem(at: url, resultingItemURL: &trashURL)
                return ("MOVED TO TRASH (space not yet freed)", true)
            } catch {
                // Fallback to manual ~/.Trash folder if system trash item fails
                let trashDir = scanner.homeDirectory.appendingPathComponent(".Trash")
                let subDir = trashDir.appendingPathComponent("devpurge.\(UUID().uuidString.prefix(8))")
                do {
                    try fm.createDirectory(at: subDir, withIntermediateDirectories: true)
                    let dest = subDir.appendingPathComponent(url.lastPathComponent)
                    try fm.moveItem(at: url, to: dest)
                    return ("MOVED TO TRASH (space not yet freed)", true)
                } catch {
                    return ("FAILED: could not move to Trash: \(error.localizedDescription)", false)
                }
            }
        } else {
            do {
                try fm.removeItem(at: url)
                return ("REMOVED", true)
            } catch {
                return ("FAILED: \(error.localizedDescription)", false)
            }
        }
    }

    public func executePlan(targets: [Target], rescue: Bool, config: DevPurgeConfig) -> [CleanupResult] {
        var results = [CleanupResult]()
        var abortRemaining = false

        for target in targets {
            if abortRemaining {
                results.append(CleanupResult(path: target.path, status: "SKIPPED: earlier cleanup failed", isSuccess: false))
                continue
            }

            let outcome = executeItem(target: target, rescue: rescue, config: config)
            results.append(CleanupResult(path: target.path, status: outcome.status, isSuccess: outcome.success))

            if outcome.status.hasPrefix("FAILED:") {
                abortRemaining = true
            }
        }

        return results
    }
}
