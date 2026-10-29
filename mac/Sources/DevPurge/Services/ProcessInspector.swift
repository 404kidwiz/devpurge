import Foundation
import AppKit

public final class ProcessInspector: @unchecked Sendable {
    public private(set) var processes: String = ""
    public private(set) var openPaths: Set<String> = []
    public private(set) var openPathHolders: [String: String] = [:]
    public private(set) var mountedImages: Set<String> = []
    public private(set) var activityError: String = ""

    private static let spawnLock = NSLock()

    public init() {}

    /// Runs an external tool without risking a pipe-buffer deadlock when output exceeds 64 KB
    /// or pipe FD inheritance across concurrent process launches.
    public static func runCommand(_ args: [String], currentDirectoryURL: URL? = nil, timeout: TimeInterval = 15) -> (stdout: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        if let cwd = currentDirectoryURL {
            process.currentDirectoryURL = cwd
        }

        // Augment PATH for GUI .app bundles launched by LaunchServices so homebrew/nvm/volta tools resolve.
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extraPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "\(home)/Library/pnpm",
            "\(home)/.volta/bin",
            "\(home)/.nvm/current/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
        process.environment = env

        spawnLock.lock()
        let outPipe = Pipe()
        let readHandle = outPipe.fileHandleForReading
        let writeHandle = outPipe.fileHandleForWriting
        _ = fcntl(readHandle.fileDescriptor, F_SETFD, FD_CLOEXEC)
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice

        let launched: Bool
        do {
            try process.run()
            launched = true
        } catch {
            launched = false
        }
        try? writeHandle.close()
        spawnLock.unlock()

        guard launched else {
            try? readHandle.close()
            return ("", -1)
        }

        final class DataBox: @unchecked Sendable { var data = Data() }
        let box = DataBox()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            box.data = (try? readHandle.readToEnd()) ?? Data()
            readGroup.leave()
        }

        let exitGroup = DispatchGroup()
        exitGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            exitGroup.leave()
        }

        if exitGroup.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            try? readHandle.close()
            _ = exitGroup.wait(timeout: .now() + 1)
            return ("", -1)
        }

        _ = readGroup.wait(timeout: .now() + timeout)
        try? readHandle.close()
        let output = String(data: box.data, encoding: .utf8) ?? ""
        return (output, process.terminationStatus)
    }

    /// Passive macOS system daemons that memory-map bundle localization tables (.strings / .loctable)
    /// without actually running or mutating the cached bundle.
    private static let passiveSystemCommands: Set<String> = [
        "Notificat",
        "NotificationCenter",
        "usernoted",
        "lsd",
        "iconservicesagent"
    ]

    public func refresh() {
        activityError = ""
        openPaths = []
        openPathHolders = [:]
        mountedImages = []

        let psResult = Self.runCommand(["ps", "-axo", "args="])
        if psResult.exitCode != 0 {
            activityError = "process inventory unavailable"
            return
        }
        processes = psResult.stdout

        // Exclude passive working-directory fds (-d ^cwd) and capture command + path (-F cn)
        // so we can ignore passive NotificationCenter localization reads and identify active holders.
        let lsofResult = Self.runCommand(["lsof", "-w", "-nP", "-d", "^cwd", "-F", "cn"], timeout: 20)
        if !lsofResult.stdout.isEmpty {
            let lines = lsofResult.stdout.split(separator: "\n")
            var paths = Set<String>()
            var holders: [String: String] = [:]
            var currentCommand = ""
            for line in lines {
                if line.hasPrefix("c") {
                    currentCommand = String(line.dropFirst())
                } else if line.hasPrefix("n") {
                    let filePath = String(line.dropFirst())
                    guard filePath.hasPrefix("/") else { continue }
                    if Self.passiveSystemCommands.contains(currentCommand) &&
                        (filePath.hasSuffix(".strings") || filePath.hasSuffix(".loctable") || filePath.hasSuffix(".icns")) {
                        continue
                    }
                    paths.insert(filePath)
                    if !currentCommand.isEmpty && holders[filePath] == nil {
                        holders[filePath] = currentCommand
                    }
                }
            }
            openPaths = paths
            openPathHolders = holders
        }

        let hdiResult = Self.runCommand(["hdiutil", "info", "-plist"])
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
        if let matchedOpenPath = openPaths.first(where: { $0 == path || $0.hasPrefix(prefix) }) {
            if let holder = openPathHolders[matchedOpenPath], !holder.isEmpty {
                return (.inUse, "Open files or a mounted disk image (\(holder))")
            }
            return (.inUse, "Open files or a mounted disk image")
        }
        if mountedImages.contains(where: { $0 == path || $0.hasPrefix(prefix) }) {
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
            if Self.updaterRunning(processes: processes, bundle: bundle, appPaths: appPaths) {
                return (.inUse, "An app updater is running")
            }
        }

        return nil
    }

    /// Only the owning app's updater can be rewriting its caches or installers.
    /// Sparkle and ShipIt name the app's bundle id or .app path in their command
    /// line; an unrelated updater (e.g. Tailscale's) must not block every target.
    public static func updaterRunning(processes: String, bundle: String, appPaths: [String]) -> Bool {
        processes.split(separator: "\n").contains { line in
            ["Autoupdate", "ShipIt", "org.sparkle-project"].contains { line.contains($0) } &&
                (line.contains(bundle) || appPaths.contains { line.contains($0) })
        }
    }

    public var isPackageManagerRunning: Bool {
        let pattern = #"\b(?:pnpm|npm)(?:\.cjs|\.js)?\s+(?:install|add|update|prune|store)\b"#
        return processes.range(of: pattern, options: .regularExpression) != nil
    }
}
