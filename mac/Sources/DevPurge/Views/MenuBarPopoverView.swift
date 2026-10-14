import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject var viewModel: DevPurgeViewModel
    @Environment(\.openWindow) private var openWindow

    public init(viewModel: DevPurgeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("d/")
                    .font(Theme.monoFont(size: 16))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.dynamicAccent)

                Text("DevPurge")
                    .font(Theme.headingFont(size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.dynamicInk)

                Spacer()

                Text(viewModel.diskSpace.formattedFree + " free")
                    .font(Theme.monoFont(size: 11))
                    .foregroundColor(Theme.dynamicMuted)
            }

            // Disk Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.dynamicLine)
                            .frame(height: 4)

                        Capsule()
                            .fill(Theme.dynamicAccent)
                            .frame(width: max(0, geo.size.width * CGFloat(viewModel.diskSpace.freeFraction)), height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("\(viewModel.targets.count) scanned locations")
                        .font(Theme.bodyFont(size: 11))
                        .foregroundColor(Theme.dynamicMuted)

                    Spacer()

                    Text("\(viewModel.eligibleCount) eligible")
                        .font(Theme.bodyFont(size: 11))
                        .foregroundColor(viewModel.eligibleCount > 0 ? Theme.dynamicAccent : Theme.dynamicMuted)
                }
            }

            Divider().background(Theme.dynamicLine)

            // Actions
            HStack(spacing: 8) {
                Button(action: {
                    viewModel.scan()
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isScanning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(viewModel.isScanning ? "Scanning..." : "Scan Now")
                            .font(Theme.headingFont(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Theme.dynamicSoft)
                    .foregroundColor(Theme.dynamicAccent)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isScanning)

                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.canBecomeMain {
                        window.makeKeyAndOrderFront(nil)
                        return
                    }
                }) {
                    Text("Open Dashboard")
                        .font(Theme.headingFont(size: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.dynamicAccent)
                        .foregroundColor(Theme.dynamicOnAccent)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(Theme.dynamicSurface)
    }
}
