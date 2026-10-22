import Foundation

/// Decimal byte formatting (1 GB = 10^9 bytes, like Finder). Mirrors src/units.py and
/// src/web/units.js; tests/units_cases.json keeps all three copies identical.
/// Uses a fixed format instead of ByteCountFormatter so every surface prints the same string.
public enum ByteFormat {
    private static let units: [(size: Double, label: String, digits: Int)] = [
        (1e12, "TB", 2), (1e9, "GB", 2), (1e6, "MB", 1), (1e3, "KB", 1),
    ]

    public static func string(_ bytes: Int64?) -> String {
        guard let bytes else { return "unknown" }
        let n = Double(bytes)
        for (i, unit) in units.enumerated() where n >= unit.size {
            var chosen = unit
            var text = format(n / chosen.size, digits: chosen.digits)
            // 999,960 bytes would print "1000.0 KB"; step up to "1.0 MB" instead.
            if (Double(text) ?? 0) >= 1000 && i > 0 {
                chosen = units[i - 1]
                text = format(n / chosen.size, digits: chosen.digits)
            }
            return "\(text) \(chosen.label)"
        }
        return "\(bytes) B"
    }

    private static func format(_ value: Double, digits: Int) -> String {
        // POSIX locale: always "1.5", never "1,5", to match the CLI and web GUI.
        String(format: "%.\(digits)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
