import SwiftUI

public struct CategoryBreakdown: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let bytes: Int64
    public let color: Color
}

public struct StorageBreakdownBarView: View {
    let targets: [Target]

    public init(targets: [Target]) {
        self.targets = targets
    }

    private var totalBytes: Int64 {
        targets.compactMap { $0.sizeBytes }.reduce(0, +)
    }

    private var categories: [CategoryBreakdown] {
        guard totalBytes > 0 else { return [] }

        var byCat: [String: Int64] = [:]
        for t in targets {
            if let size = t.sizeBytes {
                byCat[t.category, default: 0] += size
            }
        }

        let palette: [String: (title: String, color: Color)] = [
            "browsers": ("Browsers", Color(red: 0x4a/255.0, green: 0x85/255.0, blue: 0x68/255.0)),
            "installers": ("Installers", Color(red: 0xb5/255.0, green: 0x8a/255.0, blue: 0x42/255.0)),
            "oldstores": ("Package Stores", Color(red: 0x3d/255.0, green: 0x6e/255.0, blue: 0x8f/255.0)),
            "review": ("Tooling & Review", Color(red: 0x85/255.0, green: 0x60/255.0, blue: 0x94/255.0))
        ]

        var list = [CategoryBreakdown]()
        for (cat, bytes) in byCat.sorted(by: { $0.value > $1.value }) {
            let info = palette[cat] ?? (cat.capitalized, Theme.dynamicMuted)
            list.append(CategoryBreakdown(id: cat, title: info.title, bytes: bytes, color: info.color))
        }
        return list
    }

    public var body: some View {
        if totalBytes > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("STORAGE DISTRIBUTION")
                        .font(Theme.monoFont(size: 11))
                        .tracking(1.4)
                        .foregroundColor(Theme.dynamicMuted)

                    Spacer()

                    Text("Total: \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.dynamicMuted)
                }

                // Proportional stacked bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(categories) { cat in
                            let fraction = CGFloat(cat.bytes) / CGFloat(totalBytes)
                            let barWidth = max(4.0, geo.size.width * fraction - 2)
                            Rectangle()
                                .fill(cat.color)
                                .frame(width: barWidth, height: 10)
                                .help("\(cat.title): \(ByteCountFormatter.string(fromByteCount: cat.bytes, countStyle: .file))")
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 10)

                // Legend
                HStack(spacing: 16) {
                    ForEach(categories) { cat in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 7, height: 7)

                            Text(cat.title)
                                .font(Theme.bodyFont(size: 12))
                                .foregroundColor(Theme.dynamicInk)

                            Text(ByteCountFormatter.string(fromByteCount: cat.bytes, countStyle: .file))
                                .font(Theme.monoFont(size: 11))
                                .foregroundColor(Theme.dynamicMuted)
                        }
                    }
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(Theme.dynamicSurface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.dynamicLine, lineWidth: 1)
            )
        }
    }
}
