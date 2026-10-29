import SwiftUI

/// Three taped sticky notes: free space, stored size, eligible locations.
public struct StorageMetricsView: View {
    @ObservedObject var viewModel: DevPurgeViewModel
    /// Stack the notes vertically when the window is narrow.
    var stacked = false

    private var eligibleBytes: Int64 {
        viewModel.targets.filter { $0.status == .eligible }.compactMap(\.sizeBytes).reduce(0, +)
    }

    public var body: some View {
        if stacked {
            VStack(alignment: .leading, spacing: 16) { notes }
        } else {
            HStack(alignment: .top, spacing: 12) { notes }
        }
    }

    @ViewBuilder
    private var notes: some View {
        note(index: 0, angle: -1.2, tape: Theme.current.tapeB,
             label: "Available on disk",
             value: viewModel.diskSpace.formattedFree,
             caption: "of \(viewModel.diskSpace.formattedTotal)",
             meter: 1 - viewModel.diskSpace.usedFraction)
        note(index: 1, angle: 0.8, tape: Theme.current.tapeA,
             label: "Stored in scanned locations",
             value: viewModel.targets.isEmpty ? "—" : ByteFormat.string(viewModel.totalScannedStoredBytes),
             caption: "Includes items we’ll keep",
             meter: nil)
        note(index: 2, angle: -0.6, tape: Theme.current.tapeA,
             label: "Eligible locations",
             value: viewModel.targets.isEmpty ? "—" : ByteFormat.string(eligibleBytes),
             caption: viewModel.targets.isEmpty ? "Rechecked before cleanup" : "\(viewModel.eligibleCount) locations · rechecked",
             meter: nil)
    }

    private func note(index: Int, angle: Double, tape: Color, label: String, value: String, caption: String, meter: Double?) -> some View {
        let colors = Theme.notes[index]
        return VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(Theme.bodyFont(size: 12))
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(Theme.headingFont(size: 30))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let meter {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(colors.fg.opacity(0.2))
                        Capsule().fill(colors.fg).frame(width: max(0, g.size.width * meter))
                    }
                }
                .frame(height: 5)
            }
            Text(caption)
                .font(Theme.bodyFont(size: 11))
                .fixedSize(horizontal: false, vertical: true)
                .opacity(0.85)
        }
        .foregroundColor(colors.fg)
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .paper(colors.bg, seed: 50 + index, depth: 2.5)
        .overlay(Tape(color: tape, width: 52, angle: angle * 3).offset(y: -8), alignment: .top)
        .rotationEffect(.degrees(angle))
        .accessibilityElement(children: .combine)
    }
}
