import Foundation
import AppKit

public final class ProcessInspector: @unchecked Sendable {
    public private(set) var processes: String = ""
    public private(set) var openPaths: Set<String> = []
    public private(set) var mountedImages: Set<String> = []
    public private(set) var activityError: String = ""

    public init() {}

    private func runCommand(_ args: [String], timeout: TimeInterval = 15) -> (stdout: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global().async {
                process.waitUntilExit()
                group.leave()
            }
            if group.wait(timeout: .now() + timeout) == .timedOut {
                process.terminate()
                return ("", -1)
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, process.terminationStatus)
        } catch {
            return ("", -1)
        }
    }

    public func refresh() {
        activityError = ""
        openPaths = []
        mountedImages = []

        let psResult = runCommand(["ps", "-axo", "args="])
        if psResult.exitCode != 0 {
            activityError = "process inventory unavailable"
            return
        }
        processes = psResult.stdout

        let lsofResult = runCommand(["lsof", "-nP", "-F", "n"], timeout: 30)
        if lsofResult.exitCode == 0 {
            let lines = lsofResult.stdout.split(separator: "\n")
            var paths = Set<String>()
            for line in lines where line.hasPrefix("n") {
                paths.insert(String(line.dropFirst()))
            }
            openPaths = paths
        }

        let hdiResult = runCommand(["hdiutil", "info", "-plist"])
        if hdiResult.exitCode == 0, let data = hdiResult.stdout.data(using: .utf8) {
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let images = plist["images"] as? [[String: Any]] {
                var mounted = Set<String>()
                for item in images {
                    if let imagePath = item["image-path"] as? String, !imagePath.isEmpty {
                        mounted.insert(imagePath)
                    }
                }
                mountedImages = mounted
            }
        }
    }

    public func active(path: String, bundle: String?, appPaths: [String] = []) -> (status: TargetStatus, reason: String)? {
        if !activityError.isEmpty {
            return (.review, activityError)
        }

        let prefix = path.hasSuffix("/") ? path : path + "/"
        let isOpenOrMounted = openPaths.contains(where: { $0 == path || $0.hasPrefix(prefix) }) ||
                              mountedImages.contains(where: { $0 == path || $0.hasPrefix(prefix) })

        if isOpenOrMounted {
            return (.inUse, "Open files or a mounted disk image")
        }

        if let bundle = bundle {
            if appPaths.isEmpty {
                return (.review, "Owning app could not be identified")
            }
            let isRunningInWorkspace = NSWorkspace.shared.runningApplications.contains { app in
                app.bundleIdentifier == bundle
            }
            let isRunningInPs = appPaths.contains { appPath in
                let target = appPath.hasSuffix("/") ? appPath : appPath + "/"
                return processes.contains(target)
            }
            if isRunningInWorkspace || isRunningInPs {
                return (.inUse, "Owning app is running")
            }
        }

        for updater in ["Autoupdate", "ShipIt", "org.sparkle-project"] {
            if processes.contains(updater) {
                return (.inUse, "An app updater is running")
            }
        }

        return nil
    }

    public var isPackageManagerRunning: Bool {
        let pattern = #"\b(?:pnpm|npm)(?:\.cjs|\.js)?\s+(?:install|add|update|prune|store)\b"#
        return processes.range(of: pattern, options: .regularExpression) != nil
    }
}
