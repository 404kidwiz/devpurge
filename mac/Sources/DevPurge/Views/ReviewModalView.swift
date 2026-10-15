import SwiftUI

public struct ReviewModalView: View {
    @ObservedObject var viewModel: DevPurgeViewModel
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("REVIEW BEFORE CLEANUP")
                    .font(Theme.monoFont(size: 11))
                    .tracking(1.4)
                    .foregroundColor(Theme.dynamicMuted)

                Text("Your selection. One final check.")
                    .font(Theme.headingFont(size: 22))
                    .foregroundColor(Theme.dynamicInk)
            }

            // Mode indicator note
            HStack(spacing: 8) {
                Image(systemName: viewModel.rescueMode ? "trash" : "exclamationmark.triangle")
                    .foregroundColor(viewModel.rescueMode ? Theme.dynamicAccent : Theme.dynamicWarn)
                Text(viewModel.rescueMode
                     ? "Files will be moved to macOS Trash. You can put them back if needed."
                     : "Files will be permanently removed. Native package stores will be pruned.")
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(Theme.dynamicInk)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(viewModel.rescueMode ? Theme.dynamicSoft : Theme.dynamicWarnBg)
            .cornerRadius(8)

            // Items list
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected items (\(viewModel.selectedTargets.count)):")
                    .font(Theme.headingFont(size: 13))
                    .foregroundColor(Theme.dynamicMuted)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.selectedTargets) { target in
                            HStack(alignment: .center, spacing: 12) {
                                Text(target.displayName)
                                    .font(Theme.headingFont(size: 13))
                                    .foregroundColor(Theme.dynamicInk)

                                Text(target.path)
                                    .font(Theme.monoFont(size: 11))
                                    .foregroundColor(Theme.dynamicMuted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                Text(target.formattedSize)
                                    .font(Theme.monoFont(size: 12))
                                    .foregroundColor(Theme.dynamicInk)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)

                            Divider()
                                .background(Theme.dynamicLine)
                        }
                    }
                }
                .frame(maxHeight: 240)
                .background(Theme.dynamicSurface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.dynamicLine, lineWidth: 1)
                )
            }

            // Disclaimer Note
            Text("Activity and configuration are checked again immediately before each action. Stored size is not a guarantee of reclaimed volume space.")
                .font(Theme.bodyFont(size: 12))
                .foregroundColor(Theme.dynamicMuted)

            // Dialog Actions
            HStack {
                Spacer()

                Button("Go back") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(Theme.bodyFont(size: 13))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.clear)
                .foregroundColor(Theme.dynamicInk)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.dynamicLine, lineWidth: 1)
                )

                Button("Confirm cleanup") {
                    viewModel.executeCleanup()
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(Theme.headingFont(size: 13))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Theme.dynamicAccent)
                .foregroundColor(Theme.dynamicOnAccent)
                .cornerRadius(6)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(width: 580)
        .background(Theme.dynamicBackground)
    }
}
