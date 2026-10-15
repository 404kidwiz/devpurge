import Foundation

public struct AppVersion: Comparable, Sendable, Equatable {
    public let components: [Int]

    public init?(_ string: String) {
        let parts = string.split(separator: ".")
        var numbers = [Int]()
        for part in parts {
            guard let n = Int(part) else { return nil }
            numbers.append(n)
        }
        guard !numbers.isEmpty else { return nil }
        self.components = numbers
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for i in 0..<count {
            let left = i < lhs.components.count ? lhs.components[i] : 0
            let right = i < rhs.components.count ? rhs.components[i] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

public struct InstalledApp: Sendable {
    public let url: URL
    public let bundleIdentifier: String
    public let versionString: String
    public let version: AppVersion?
    public let appName: String
}

public final class AppRegistry: @unchecked Sendable {
    public private(set) var appsByBundle: [String: [InstalledApp]] = [:]
    private let appRoots: [URL]

    public init(appRoots: [URL]? = nil) {
        if let roots = appRoots {
            self.appRoots = roots
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.appRoots = [
                URL(fileURLWithPath: "/Applications"),
                home.appendingPathComponent("Applications")
            ]
        }
    }

    public func refresh() {
        appsByBundle = [:]
        let fm = FileManager.default

        for root in appRoots {
            guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            for entry in entries where entry.pathExtension == "app" {
                let plistURL = entry.appendingPathComponent("Contents/Info.plist")
                guard let data = try? Data(contentsOf: plistURL),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      let bundle = plist["CFBundleIdentifier"] as? String else {
                    continue
                }

                let verStr = (plist["CFBundleShortVersionString"] as? String) ?? ""
                let app = InstalledApp(
                    url: entry,
                    bundleIdentifier: bundle,
                    versionString: verStr,
                    version: AppVersion(verStr),
                    appName: entry.deletingPathExtension().lastPathComponent
                )
                appsByBundle[bundle, default: []].append(app)
            }
        }
    }

    public func installedVersion(for bundle: String) throws -> AppVersion {
        let copies = appsByBundle[bundle] ?? []
        guard copies.count == 1 else {
            throw NSError(domain: "AppRegistry", code: 1, userInfo: [NSLocalizedDescriptionKey: "Installed app missing or multiple copies found"])
        }
        guard let ver = copies[0].version else {
            throw NSError(domain: "AppRegistry", code: 2, userInfo: [NSLocalizedDescriptionKey: "Version format is not comparable"])
        }
        return ver
    }

    public func findByAppName(_ name: String) -> (bundle: String, app: InstalledApp)? {
        for (bundle, apps) in appsByBundle {
            for app in apps where app.appName.caseInsensitiveCompare(name) == .orderedSame {
                return (bundle, app)
            }
        }
        return nil
    }
}
