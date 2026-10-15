import Foundation

/// Locations DevPurge must never remove, regardless of scanner results.
public enum ProtectedPaths {
    public static let protectedHomeFolders = ["Desktop", "Documents", "Downloads", "Projects", "Developer", "Library"]

    public static func reason(for url: URL, home: URL) -> String? {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let homePath = home.standardizedFileURL.resolvingSymlinksInPath().path
        if path == "/" || path.isEmpty { return "filesystem root" }
        if path == homePath || homePath.hasPrefix(path + "/") { return "home directory or one of its parents" }
        for name in protectedHomeFolders where path == homePath + "/" + name {
            return "protected folder ~/\(name)"
        }
        if URL(fileURLWithPath: path).pathComponents.contains(".git") {
            return "inside a Git repository's .git directory"
        }
        let subtrees = [
            (homePath + "/Library/Keychains", "Keychains"),
            ("/Library/Keychains", "Keychains"),
            (homePath + "/Library/Developer/Xcode/Archives", "Xcode Archives")
        ]
        for (root, label) in subtrees where path == root || path.hasPrefix(root + "/") {
            return label
        }
        return nil
    }
}
