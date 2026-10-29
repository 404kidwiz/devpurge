import SwiftUI

/// Final check before cleanup, printed like a receipt.
public struct ReviewModalView: View {
    @ObservedObject var viewModel: DevPurgeViewModel
    @Environment(\.dismiss) private var dismiss

    private var totalNote: (bg: Color, fg: Color) {
        // Ensure the receipt total highlight contrasts clearly with the primary CTA button in dark palettes.
        Theme.current.isDark ? Theme.notes[2] : Theme.notes[0]
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("REVIEW BEFORE CLEANUP")
                .font(Theme.bodyFont(size: 12))
                .tracking(1.4)
                .foregroundColor(Theme.muted)

            Text("Your selection.\nOne final check.")
                .font(Theme.headingFont(size: 36))
                .foregroundColor(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.selectedTargets) { target in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.friendlyTitle)
                                    .font(Theme.bodyFont(size: 15))
                                    .foregroundColor(Theme.ink)
                                Text(target.path)
                                    .font(Theme.bodyFont(size: 11))
                                    .foregroundColor(Theme.muted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text(target.formattedSize)
                                .font(Theme.bodyFont(size: 15))
                                .monospacedDigit()
                                .foregroundColor(Theme.ink)
                        }
                    }
                }
            }
            .frame(maxHeight: 220)

            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundColor(Theme.ink.opacity(0.6))
                .frame(height: 1)

            Text("Total: \(ByteFormat.string(viewModel.totalSelectedBytes))")
                .font(Theme.headingFont(size: 30))
                .monospacedDigit()
                .foregroundColor(totalNote.fg)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .paper(totalNote.bg, seed: 77, depth: 3, shadow: false)
                .rotationEffect(.degrees(-1))

            Button(action: { viewModel.rescueMode.toggle() }) {
                HStack(spacing: 10) {
                    ZineCheckbox(isOn: viewModel.rescueMode)
                    Text("Move files to Trash")
                        .font(Theme.bodyFont(size: 15))
                        .foregroundColor(Theme.ink)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(viewModel.rescueMode ? .isSelected : [])

            Text(viewModel.rescueMode
                 ? "Files go to the macOS Trash. You can put them back. Space is freed when you empty the Trash."
                 : "Files are removed permanently. Native package stores are pruned.")
                .font(Theme.bodyFont(size: 12))
                .foregroundColor(viewModel.rescueMode ? Theme.muted : Theme.danger)
                .fixedSize(horizontal: false, vertical: true)

            Text("Stored sizes are not guaranteed freed space. Activity is checked again right before each item.")
                .font(Theme.bodyFont(size: 12))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Spacer()
                Button("Go back") { dismiss() }
                    .buttonStyle(ZineButtonStyle(kind: .secondary, size: 17))
                    .keyboardShortcut(.cancelAction)
                Button("Confirm cleanup") {
                    viewModel.executeCleanup()
                    dismiss()
                }
                .buttonStyle(ZineButtonStyle(kind: .primary, size: 17))
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 34)
        .padding(.top, 34)
        .padding(.bottom, 40)
        .frame(width: 520)
        .background(
            TornShape(seed: 9, depth: 6, bottomOnly: true)
                .fill(Theme.surface)
                .overlay(TornShape(seed: 9, depth: 6, bottomOnly: true).fill(PaperGrain.image).opacity(0.12).blendMode(.multiply))
        )
        .overlay(Tape(color: Theme.current.tapeA, width: 120, angle: -2).offset(y: -4), alignment: .top)
        .background(Theme.background)
    }
}
