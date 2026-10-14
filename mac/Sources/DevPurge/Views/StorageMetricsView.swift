import SwiftUI

public struct StorageMetricsView: View {
    @ObservedObject var viewModel: DevPurgeViewModel

    public var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 620 {
                horizontalLayout
            } else {
                compactStackedLayout
            }
        }
        .frame(minHeight: 140)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Theme.dynamicSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.dynamicLine, lineWidth: 1)
        )
    }

    // Wide horizontal layout with dividers
    private var horizontalLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            diskMetricCard
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 20)

            Divider().background(Theme.dynamicLine)

            scannedMetricCard
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            Divider().background(Theme.dynamicLine)

            eligibleMetricCard
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
        }
    }

    // Narrow responsive layout
    private var compactStackedLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            diskMetricCard

            Divider().background(Theme.dynamicLine)

            HStack(spacing: 16) {
                scannedMetricCard
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(Theme.dynamicLine)

                eligibleMetricCard
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // Individual metric card views
    private var diskMetricCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Available on disk")
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(Theme.dynamicMuted)

            Text(viewModel.diskSpace.formattedFree)
                .font(Theme.headingFont(size: 32))
                .foregroundColor(Theme.dynamicInk)

            // Dynamic meter bar
            GeometryReader { meterGeo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.dynamicLine)
                        .frame(height: 4)

                    Capsule()
                        .fill(Theme.dynamicAccent)
                        .frame(width: max(0, meterGeo.size.width * CGFloat(viewModel.diskSpace.freeFraction)), height: 4)
                }
            }
            .frame(height: 6)
            .padding(.vertical, 2)

            Text("Total volume: \(viewModel.diskSpace.formattedTotal)")
                .font(Theme.bodyFont(size: 11))
                .foregroundColor(Theme.dynamicMuted)
        }
    }

    private var scannedMetricCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Stored in scanned locations")
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(Theme.dynamicMuted)

            Text(viewModel.targets.isEmpty ? "—" : ByteCountFormatter.string(fromByteCount: viewModel.totalScannedStoredBytes, countStyle: .file))
                .font(Theme.headingFont(size: 32))
                .foregroundColor(Theme.dynamicInk)

            Text("Includes items we’ll keep")
                .font(Theme.bodyFont(size: 11))
                .foregroundColor(Theme.dynamicMuted)
        }
    }

    private var eligibleMetricCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Eligible locations")
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(Theme.dynamicMuted)

            Text(viewModel.targets.isEmpty ? "—" : "\(viewModel.eligibleCount)")
                .font(Theme.headingFont(size: 32))
                .foregroundColor(Theme.dynamicInk)

            Text("Rechecked before cleanup")
                .font(Theme.bodyFont(size: 11))
                .foregroundColor(Theme.dynamicMuted)
        }
    }
}
