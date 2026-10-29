import Foundation

public enum TargetStatus: String, Codable, Sendable {
    case eligible = "eligible"
    case inUse = "in-use"
    case review = "review"
    case ignored = "ignored"

    public var badgeLabel: String {
        switch self {
        case .eligible: return "Eligible"
        case .inUse: return "In use"
        case .review: return "Review"
        case .ignored: return "Ignored"
        }
    }
}

public struct Target: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let path: String
    public let category: String
    public var status: TargetStatus
    public var reason: String
    public var command: [String]
    public var sizeBytes: Int64?
    public var sizeError: String

    public init(
        id: String = UUID().uuidString,
        path: String,
        category: String,
        status: TargetStatus = .review,
        reason: String = "No supported safe cleanup action",
        command: [String] = [],
        sizeBytes: Int64? = nil,
        sizeError: String = ""
    ) {
        self.id = id
        self.path = path
        self.category = category
        self.status = status
        self.reason = reason
        self.command = command
        self.sizeBytes = sizeBytes
        self.sizeError = sizeError
    }

    /// Raw last path component (kept for backwards compatibility with engine tests).
    public var displayName: String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    /// Context-rich label for UI rows so multiple browser caches or updater archives are immediately distinguishable.
    public var friendlyTitle: String {
        let p = path
        if category == "projects" {
            let url = URL(fileURLWithPath: p)
            let parent = url.deletingLastPathComponent().lastPathComponent
            if !parent.isEmpty && parent != "/" {
                return "\(parent) · \(displayName)"
            }
        }

        // Browser caches: .../Library/Caches/<Browser>/<Profile>/<Cache|Code Cache>
        let browserLabels: [(marker: String, name: String)] = [
            ("/Library/Caches/Google/Chrome/", "Google Chrome"),
            ("/Library/Caches/BrowserClaw/", "BrowserClaw"),
            ("/Library/Caches/BrowserOS/", "BrowserOS"),
            ("/Library/Caches/Comet/", "Perplexity Comet"),
        ]
        for (marker, name) in browserLabels {
            if let range = p.range(of: marker) {
                let rest = p[range.upperBound...].split(separator: "/")
                if rest.count >= 2 {
                    let profile = String(rest[0])
                    let cacheKind = String(rest.last!)
                    return profile == "Default"
                        ? "\(name) · \(cacheKind)"
                        : "\(name) (\(profile)) · \(cacheKind)"
                }
                return "\(name) · \(displayName)"
            }
        }

        // Updaters & Sparkle installers
        let updaterLabels: [(marker: String, name: String)] = [
            ("/@zcodedesktop-updater", "ZCode Updater"),
            ("/@opencode-aidesktop-updater", "OpenCode Updater"),
            ("/@granolaelectron-updater", "Granola Updater"),
            ("/com.openai.codex/org.sparkle-project.Sparkle/", "Codex Sparkle Update"),
            ("/com.browseros.BrowserClaw/org.sparkle-project.Sparkle/", "BrowserClaw Sparkle Update"),
        ]
        for (marker, name) in updaterLabels where p.contains(marker) {
            return "\(name) · \(displayName)"
        }

        // Package stores & developer caches
        if p.contains("/pnpm/store/") {
            return "pnpm Store · \(displayName)"
        }
        if p.hasSuffix("/.npm/_cacache") {
            return "npm Cache (_cacache)"
        }
        if p.hasSuffix("/.cargo/registry") {
            return "Cargo Registry"
        }
        if p.hasSuffix("/Xcode/DerivedData") {
            return "Xcode DerivedData"
        }
        if p.hasSuffix("/CoreSimulator/Devices") {
            return "Xcode Simulator Devices"
        }
        if p.hasSuffix("/Caches/Homebrew") {
            return "Homebrew Cache"
        }
        if p.hasSuffix("/.gradle/caches") {
            return "Gradle Caches"
        }
        if p.hasSuffix("/.cache/uv") {
            return "uv Python Cache"
        }
        if p.hasSuffix("/Caches/ms-playwright") {
            return "Playwright Browsers"
        }
        if p.hasSuffix("/.cache/huggingface") {
            return "Hugging Face Models"
        }
        if p.hasSuffix("/.cache/codex-runtimes") {
            return "Codex Runtimes"
        }
        if p.contains("/com.docker.docker/Data/vms") {
            return "Docker Desktop VMs"
        }

        return displayName
    }

    /// Safe, non-destructive native tooling prune command that preserves active runtimes/environments.
    public var nativePruneSpec: (label: String, command: [String])? {
        if path.hasSuffix("/.cache/uv") {
            return ("Prune unused (uv cache prune)", ["uv", "cache", "prune"])
        }
        if path.hasSuffix("/.npm/_cacache") {
            return ("Verify & GC (npm cache verify)", ["npm", "cache", "verify"])
        }
        if path.contains("/pnpm/store/") {
            let cmd = command.isEmpty ? ["pnpm", "store", "prune"] : command
            return ("Prune unreferenced (pnpm store prune)", cmd)
        }
        if path.hasSuffix("/CoreSimulator/Devices") {
            return ("Prune unavailable (simctl delete unavailable)", ["xcrun", "simctl", "delete", "unavailable"])
        }
        return nil
    }

    /// Suggested terminal command for review items.
    public var cliSuggestion: String? {
        if path.hasSuffix("/.cache/uv") {
            return "devpurge --uv"
        }
        if path.hasSuffix("/.npm/_cacache") || path.contains("/pnpm/store/") {
            return "devpurge --node"
        }
        if path.hasSuffix("/Xcode/DerivedData") {
            return "devpurge --mac"
        }
        if path.hasSuffix("/CoreSimulator/Devices") {
            return "xcrun simctl delete unavailable"
        }
        if path.contains("/com.docker.docker/Data/vms") {
            return "docker system df"
        }
        return nil
    }

    public var formattedSize: String {
        guard let size = sizeBytes else { return "—" }
        return ByteFormat.string(size)
    }
}
