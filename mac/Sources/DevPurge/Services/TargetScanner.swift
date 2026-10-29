import Foundation

public final class TargetScanner: @unchecked Sendable {
    public let homeDirectory: URL
    public let cacheDirectory: URL
    public let appRegistry: AppRegistry
    public let processInspector: ProcessInspector

    private let browsers: [String: String] = [
        "Comet": "ai.perplexity.comet",
        "BrowserClaw": "com.browseros.BrowserClaw",
        "BrowserOS": "com.browseros.BrowserOS",
        "Google/Chrome": "com.google.Chrome"
    ]

    private let updaters: [String: String] = [
        "@zcodedesktop-updater": "ZCode",
        "@opencode-aidesktop-updater": "OpenCode",
        "@granolaelectron-updater": "Granola"
    ]

    private let sparkleBundles = ["com.openai.codex", "com.browseros.BrowserClaw"]

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        appRegistry: AppRegistry = AppRegistry(),
        processInspector: ProcessInspector = ProcessInspector()
    ) {
        self.homeDirectory = homeDirectory
        self.cacheDirectory = homeDirectory.appendingPathComponent("Library/Caches")
        self.appRegistry = appRegistry
        self.processInspector = processInspector
    }

    private func isAllowedPath(_ url: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath()
        guard resolved.standardizedFileURL.path == url.standardizedFileURL.path else {
            return false
        }
        let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values?.isSymbolicLink == true {
            return false
        }

        let pnpmStore1 = homeDirectory.appendingPathComponent("Library/pnpm/store").standardizedFileURL.path
        let pnpmStore2 = homeDirectory.appendingPathComponent(".local/share/pnpm/store").standardizedFileURL.path
        let cachePath = cacheDirectory.standardizedFileURL.path

        let targetPath = url.standardizedFileURL.path
        return targetPath.hasPrefix(cachePath + "/") ||
               targetPath.hasPrefix(pnpmStore1 + "/") ||
               targetPath.hasPrefix(pnpmStore2 + "/")
    }

    private func classify(target: inout Target, bundle: String? = nil) {
        let url = URL(fileURLWithPath: target.path)
        guard isAllowedPath(url) else {
            target.status = .review
            target.reason = "Symlink or path outside supported cache roots"
            return
        }

        let appPaths = bundle != nil ? (appRegistry.appsByBundle[bundle!] ?? []).map { $0.url.path } : []
        if let activity = processInspector.active(path: target.path, bundle: bundle, appPaths: appPaths) {
            target.status = activity.status
            target.reason = activity.reason
        } else {
            target.status = .eligible
            target.reason = "Inactive cache; can be regenerated"
        }
    }

    public func collectBrowserTargets() -> [Target] {
        var targets = [Target]()
        let fm = FileManager.default

        for (directory, bundle) in browsers {
            let root = cacheDirectory.appendingPathComponent(directory)
            guard let profiles = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for profile in profiles {
                let name = profile.lastPathComponent
                if name != "Default" && name.range(of: #"^Profile \d+$"#, options: .regularExpression) == nil {
                    continue
                }
                for cacheName in ["Cache", "Code Cache"] {
                    let cachePath = profile.appendingPathComponent(cacheName)
                    if fm.fileExists(atPath: cachePath.path) {
                        var target = Target(path: cachePath.path, category: "browsers")
                        classify(target: &target, bundle: bundle)
                        targets.append(target)
                    }
                }
            }
        }
        return targets
    }

    public func collectInstallerTargets() -> [Target] {
        var targets = [Target]()
        let fm = FileManager.default

        for bundle in sparkleBundles {
            let root = cacheDirectory.appendingPathComponent("\(bundle)/org.sparkle-project.Sparkle/Installation")
            guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for dir in dirs {
                var target = Target(path: dir.path, category: "installers")
                do {
                    var foundPlist: URL?
                    if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) {
                        for case let fileURL as URL in enumerator {
                            if fileURL.path.hasSuffix(".app/Contents/Info.plist") {
                                if foundPlist != nil {
                                    throw NSError(domain: "DevPurge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Installer app/version could not be identified"])
                                }
                                foundPlist = fileURL
                            }
                        }
                    }
                    guard let plistURL = foundPlist,
                          let data = try? Data(contentsOf: plistURL),
                          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                        throw NSError(domain: "DevPurge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Installer app/version could not be identified"])
                    }
                    let installerBundle = (plist["CFBundleIdentifier"] as? String) ?? ""
                    if installerBundle != bundle {
                        throw NSError(domain: "DevPurge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Installer bundle does not match its cache owner"])
                    }
                    let verStr = (plist["CFBundleShortVersionString"] as? String) ?? ""
                    guard let installerVer = AppVersion(verStr) else {
                        throw NSError(domain: "DevPurge", code: 3, userInfo: [NSLocalizedDescriptionKey: "Version format is not comparable"])
                    }
                    let installedVer = try appRegistry.installedVersion(for: bundle)
                    if installerVer > installedVer {
                        throw NSError(domain: "DevPurge", code: 4, userInfo: [NSLocalizedDescriptionKey: "Newer update is pending; retain it"])
                    }
                    let attrs = try fm.attributesOfItem(atPath: dir.path)
                    if let mtime = attrs[.modificationDate] as? Date, Date().timeIntervalSince(mtime) < 86400 {
                        throw NSError(domain: "DevPurge", code: 5, userInfo: [NSLocalizedDescriptionKey: "Installer is less than one day old; retain it"])
                    }
                    classify(target: &target, bundle: bundle)
                } catch {
                    target.status = .review
                    target.reason = error.localizedDescription
                }
                targets.append(target)
            }
        }

        for (directory, appName) in updaters {
            let root = cacheDirectory.appendingPathComponent(directory)
            guard fm.fileExists(atPath: root.path) else { continue }
            var archives = [URL]()
            if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator where fileURL.pathExtension == "zip" {
                    archives.append(fileURL)
                }
            }
            if archives.isEmpty {
                targets.append(Target(path: root.path, category: "installers", reason: "No identifiable updater archive"))
                continue
            }
            for archive in archives {
                var target = Target(path: archive.path, category: "installers")
                do {
                    guard let candidate = appRegistry.findByAppName(appName) else {
                        throw NSError(domain: "DevPurge", code: 6, userInfo: [NSLocalizedDescriptionKey: "Installed app could not be uniquely identified"])
                    }
                    let attrs = try fm.attributesOfItem(atPath: archive.path)
                    if let mtime = attrs[.modificationDate] as? Date, Date().timeIntervalSince(mtime) < 86400 {
                        throw NSError(domain: "DevPurge", code: 7, userInfo: [NSLocalizedDescriptionKey: "Archive is less than one day old; retain it"])
                    }
                    classify(target: &target, bundle: candidate.bundle)
                } catch {
                    target.status = .review
                    target.reason = error.localizedDescription
                }
                targets.append(target)
            }
        }

        return targets
    }

    public func collectOldStoreTargets() -> [Target] {
        var targets = [Target]()
        let fm = FileManager.default

        var activeStorePath: String?
        let pnpmRes = ProcessInspector.runCommand(["pnpm", "store", "path"], currentDirectoryURL: homeDirectory, timeout: 10)
        if pnpmRes.exitCode == 0 {
            let out = pnpmRes.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if out.hasPrefix("/") {
                activeStorePath = URL(fileURLWithPath: out).resolvingSymlinksInPath().path
            }
        }

        var managers: [String: [String]] = [:]
        for toolsDir in [
            homeDirectory.appendingPathComponent("Library/pnpm/.tools/pnpm"),
            homeDirectory.appendingPathComponent(".local/share/pnpm/.tools/pnpm")
        ] {
            guard let contents = try? fm.contentsOfDirectory(at: toolsDir, includingPropertiesForKeys: nil) else { continue }
            for verDir in contents {
                let pnpmCjs = verDir.appendingPathComponent("node_modules/pnpm/bin/pnpm.cjs")
                if fm.fileExists(atPath: pnpmCjs.path) {
                    let res = ProcessInspector.runCommand(["node", pnpmCjs.path, "store", "path"], currentDirectoryURL: homeDirectory, timeout: 10)
                    if res.exitCode == 0 {
                        let out = res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                        if out.hasPrefix("/") {
                            let resolved = URL(fileURLWithPath: out).resolvingSymlinksInPath().path
                            managers[resolved] = ["node", pnpmCjs.path, "store", "prune"]
                        }
                    }
                }
            }
        }

        for storeRoot in [
            homeDirectory.appendingPathComponent("Library/pnpm/store"),
            homeDirectory.appendingPathComponent(".local/share/pnpm/store")
        ] {
            guard let versions = try? fm.contentsOfDirectory(at: storeRoot, includingPropertiesForKeys: nil) else { continue }
            for vDir in versions {
                let name = vDir.lastPathComponent
                guard name.range(of: #"^v\d+$"#, options: .regularExpression) != nil else { continue }
                var target = Target(path: vDir.path, category: "oldstores")
                let resolved = vDir.resolvingSymlinksInPath().path

                if activeStorePath == nil {
                    target.reason = "Active pnpm store could not be verified"
                } else if resolved == activeStorePath {
                    target.reason = "Active pnpm store; use --node"
                } else if managers[resolved] == nil {
                    target.reason = "No installed pnpm version verified for this store; never delete it directly"
                } else if processInspector.isPackageManagerRunning {
                    target.status = .inUse
                    target.reason = "A package manager is running"
                } else {
                    classify(target: &target)
                    if let cmd = managers[resolved] {
                        target.command = cmd
                    }
                    if target.status == .eligible {
                        target.reason = "Native pnpm prune only; savings are unknown"
                    }
                }
                targets.append(target)
            }
        }

        return targets
    }

    public func collectReviewTargets() -> [Target] {
        let reviewList = [
            (".cache/uv", "Use --uv for native pruning; installed runtimes may share these files"),
            (".npm/_cacache", "Use --node"),
            ("Library/Developer/Xcode/DerivedData", "Close Xcode/builds, then use --mac"),
            ("Library/Developer/CoreSimulator/Devices", "Use simctl delete unavailable to prune obsolete simulator runtimes"),
            ("Library/Caches/ms-playwright", "Retain registered browser versions"),
            (".cache/huggingface", "Model files require individual review"),
            (".cache/codex-runtimes", "Installed runtimes require individual review"),
            ("Library/Containers/com.docker.docker/Data/vms", "Docker VM includes persistent data; inspect through Docker")
        ]

        var targets = [Target]()
        let fm = FileManager.default

        for (relPath, reason) in reviewList {
            let fullURL = homeDirectory.appendingPathComponent(relPath)
            if fm.fileExists(atPath: fullURL.path) {
                var target = Target(path: fullURL.path, category: "review")
                if let activity = processInspector.active(path: fullURL.path, bundle: nil) {
                    target.status = activity.status
                    target.reason = activity.reason
                } else {
                    target.status = .review
                    target.reason = reason
                }
                targets.append(target)
            }
        }
        return targets
    }

    /// Walks user-configured project scan roots to discover stale `node_modules`, `.venv`, and Rust `target/` folders.
    public func collectProjectTargets(config: DevPurgeConfig) -> [Target] {
        guard !config.projectScanRoots.isEmpty else { return [] }
        let fm = FileManager.default
        let idleDays = max(1, config.staleProjectDays)
        let staleSeconds = TimeInterval(idleDays * 86400)
        var targets = [Target]()
        var seenPaths = Set<String>()

        func walkDirectory(_ dirURL: URL, depth: Int) {
            if depth > 4 { return }
            guard let children = try? fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
                options: [.skipsPackageDescendants]
            ) else { return }

            for child in children {
                guard let vals = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]),
                      vals.isDirectory == true,
                      vals.isSymbolicLink != true else { continue }

                let name = child.lastPathComponent
                if name == ".git" || name == ".build" || name == "Library" || name == ".Trash" {
                    continue
                }

                let isNodeModules = (name == "node_modules" && fm.fileExists(atPath: dirURL.appendingPathComponent("package.json").path))
                let isPythonVenv = ((name == ".venv" || name == "venv") && (
                    fm.fileExists(atPath: child.appendingPathComponent("pyvenv.cfg").path) ||
                    fm.fileExists(atPath: dirURL.appendingPathComponent("pyproject.toml").path) ||
                    fm.fileExists(atPath: dirURL.appendingPathComponent("requirements.txt").path)
                ))
                let isCargoTarget = (name == "target" && fm.fileExists(atPath: dirURL.appendingPathComponent("Cargo.toml").path))

                if isNodeModules || isPythonVenv || isCargoTarget {
                    let stdPath = child.standardizedFileURL.path
                    guard !seenPaths.contains(stdPath),
                          ProtectedPaths.reason(for: child, home: homeDirectory) == nil else {
                        continue
                    }
                    seenPaths.insert(stdPath)

                    var target = Target(path: stdPath, category: "projects")
                    if let activity = processInspector.active(path: stdPath, bundle: nil) {
                        target.status = activity.status
                        target.reason = activity.reason
                    } else {
                        let parentVals = try? dirURL.resourceValues(forKeys: [.contentModificationDateKey])
                        let mtime = max(vals.contentModificationDate ?? .distantPast, parentVals?.contentModificationDate ?? .distantPast)
                        let ageSeconds = Date().timeIntervalSince(mtime)
                        if ageSeconds >= staleSeconds {
                            let daysOld = Int(ageSeconds / 86400)
                            target.status = .eligible
                            target.reason = "Stale project cache (\(daysOld)d idle); can be reinstalled"
                        } else {
                            target.status = .review
                            target.reason = "Recently active project (<=\(idleDays)d); kept by default"
                        }
                    }
                    targets.append(target)
                    continue
                }

                // Do not descend inside other heavy artifact folders
                if name == "node_modules" || name == ".venv" || name == "venv" || name == "target" || name.hasPrefix(".") {
                    continue
                }
                walkDirectory(child, depth: depth + 1)
            }
        }

        for rootPath in config.projectScanRoots {
            let rootURL = URL(fileURLWithPath: rootPath).standardizedFileURL
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: rootURL.path, isDirectory: &isDir), isDir.boolValue else { continue }
            walkDirectory(rootURL, depth: 0)
        }

        return targets
    }

    public static func measure(path: String) -> (sizeBytes: Int64?, sizeError: String) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            return (nil, "Size unavailable: unreadable files")
        }

        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .totalFileSizeKey,
            .fileSizeKey
        ]

        if !isDir.boolValue {
            if let vals = try? url.resourceValues(forKeys: keys) {
                let sz = vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? vals.totalFileSize ?? vals.fileSize ?? 0
                return (Int64(sz), "")
            }
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let sz = attrs[.size] as? NSNumber {
                return (sz.int64Value, "")
            }
            return (nil, "Size unavailable: unreadable files")
        }

        var total: Int64 = 0
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return (nil, "Size unavailable: unreadable files")
        }

        for case let fileURL as URL in enumerator {
            guard let vals = try? fileURL.resourceValues(forKeys: keys) else { continue }
            if vals.isSymbolicLink == true || vals.isDirectory == true { continue }
            let sz = vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? vals.totalFileSize ?? vals.fileSize ?? 0
            total += Int64(sz)
        }
        return (total, "")
    }

    public func scanStream(config: DevPurgeConfig) -> AsyncStream<Target> {
        AsyncStream { continuation in
            Task {
                self.appRegistry.refresh()
                self.processInspector.refresh()

                var candidates = [Target]()
                candidates.append(contentsOf: self.collectBrowserTargets())
                candidates.append(contentsOf: self.collectInstallerTargets())
                candidates.append(contentsOf: self.collectOldStoreTargets())
                candidates.append(contentsOf: self.collectProjectTargets(config: config))
                candidates.append(contentsOf: self.collectReviewTargets())

                for i in 0..<candidates.count {
                    if config.ignore.contains(candidates[i].category) {
                        candidates[i].status = .ignored
                        candidates[i].reason = "Ignored by DevPurge configuration"
                    }
                }

                await withTaskGroup(of: Target.self) { group in
                    for target in candidates {
                        group.addTask {
                            var measured = target
                            let m = Self.measure(path: target.path)
                            measured.sizeBytes = m.sizeBytes
                            measured.sizeError = m.sizeError
                            return measured
                        }
                    }

                    for await measuredTarget in group {
                        continuation.yield(measuredTarget)
                    }
                }

                continuation.finish()
            }
        }
    }

    public func scanAll(config: DevPurgeConfig) async -> [Target] {
        var targets = [Target]()
        for await target in scanStream(config: config) {
            targets.append(target)
        }
        return targets
    }
}
