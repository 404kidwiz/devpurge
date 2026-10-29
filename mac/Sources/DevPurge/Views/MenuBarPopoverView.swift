import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject var viewModel: DevPurgeViewModel

    public init(viewModel: DevPurgeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DevPurge / Storage desk")
                    .font(Theme.bodyFont(size: 12))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .paper(Theme.current.tapeB.opacity(0.55), seed: 5, depth: 2, shadow: false)
                    .rotationEffect(.degrees(-2))
                Spacer()
                Text(viewModel.licenseManager.badgeText)
                    .font(Theme.bodyFont(size: 11))
                    .foregroundColor(Theme.muted)
            }

            if viewModel.isLowDiskSpace {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.danger)
                        .font(.system(size: 11))
                    Text("Low disk space (< \(viewModel.config.lowDiskAlertThresholdGB) GB free)")
                        .font(Theme.bodyFont(size: 11))
                        .foregroundColor(Theme.ink)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .paper(Theme.warnBg, seed: 8, depth: 2, shadow: false)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.diskSpace.formattedFree)
                    .font(Theme.headingFont(size: 40))
                    .monospacedDigit()
                    .foregroundColor(viewModel.isLowDiskSpace ? Theme.danger : Theme.primary)
                Text("available")
                    .font(Theme.headingFont(size: 34))
                    .foregroundColor(Theme.current.isDark ? Theme.notes[2].bg : Theme.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { g in
                    let free = CGFloat(1 - viewModel.diskSpace.usedFraction)
                    HStack(spacing: 0) {
                        Rectangle().fill(Theme.notes[1].bg).frame(width: g.size.width * (1 - free) * 0.5)
                        Rectangle().fill(Theme.notes[0].bg).frame(width: g.size.width * (1 - free) * 0.5)
                        Rectangle().fill(Theme.notes[2].bg)
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 12)
                Text("STORAGE DISTRIBUTION · \(viewModel.diskSpace.formattedTotal) total")
                    .font(Theme.bodyFont(size: 11))
                    .foregroundColor(Theme.muted)
            }

            HStack {
                Text(viewModel.targets.isEmpty
                     ? "Not scanned yet"
                     : "\(viewModel.targets.count) scanned · \(viewModel.eligibleCount) eligible (\(ByteFormat.string(viewModel.totalEligibleBytes)))")
                Spacer()
            }
            .font(Theme.bodyFont(size: 12))
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .paper(Theme.surface, seed: 6, depth: 2, shadow: false)

            HStack(spacing: 10) {
                Button(action: { viewModel.scanAndSelectSafe() }) {
                    HStack(spacing: 6) {
                        if viewModel.isScanning { ProgressView().controlSize(.small) }
                        Text(viewModel.isScanning ? "Scanning…" : "Scan & Select Safe")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ZineButtonStyle(kind: .primary, size: 14))
                .disabled(viewModel.isScanning)

                Button(action: openDashboard) {
                    Text("Open Desk").frame(maxWidth: .infinity)
                }
                .buttonStyle(ZineButtonStyle(kind: .secondary, size: 14))
            }

            if !viewModel.selectedTargetIDs.isEmpty {
                Button(action: {
                    openDashboard()
                    viewModel.prepareReview()
                }) {
                    Text("Review \(ByteFormat.string(viewModel.totalSelectedBytes)) selected →")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ZineButtonStyle(kind: .secondary, size: 13))
            }

            Text("Nothing runs automatically from this dashboard.")
                .font(Theme.bodyFont(size: 11))
                .foregroundColor(Theme.muted)

            HStack {
                Text("Palette")
                    .font(Theme.bodyFont(size: 11))
                    .foregroundColor(Theme.muted)
                Spacer()
                PalettePicker(compact: true)
            }
        }
        .padding(18)
        .frame(width: 350)
        .background(Theme.background)
    }

    private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}
