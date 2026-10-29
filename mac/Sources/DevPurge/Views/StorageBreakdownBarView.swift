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

        // Category colours come from the active palette's note colours.
        let palette: [String: (title: String, color: Color)] = [
            "browsers": ("Browsers", Theme.notes[2].bg),
            "installers": ("Installers", Theme.notes[0].bg),
            "oldstores": ("Package Stores", Theme.notes[1].bg),
            "projects": ("Project Caches", Theme.primary),
            "review": ("Tooling & Review", Theme.accent)
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

                    Text("Total: \(ByteFormat.string(totalBytes))")
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
                                .frame(width: barWidth, height: 14)
                                .help("\(cat.title): \(ByteFormat.string(cat.bytes))")
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 14)

                // Legend
                HStack(spacing: 16) {
                    ForEach(categories) { cat in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 7, height: 7)

                            Text(cat.title)
                                .font(Theme.bodyFont(size: 13))
                                .foregroundColor(Theme.dynamicInk)

                            Text(ByteFormat.string(cat.bytes))
                                .font(Theme.monoFont(size: 11))
                                .foregroundColor(Theme.dynamicMuted)
                        }
                    }
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .paper(Theme.surface, seed: 40, depth: 2, shadow: false)
        }
    }
}
