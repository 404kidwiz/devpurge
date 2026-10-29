import SwiftUI

/// Summary of the last cleanup. Reports Trash moves and measured free space
/// separately so the headline never overstates what was reclaimed.
public struct ResultsView: View {
    @ObservedObject var viewModel: DevPurgeViewModel

    private var results: [CleanupResult] { viewModel.cleanupResults }
    private var okCount: Int { results.filter(\.isSuccess).count }

    private var headline: String {
        if viewModel.lastCleanupUsedTrash {
            return "\(ByteFormat.string(viewModel.lastCleanupStoredBytes)) in the Trash"
        }
        return "\(ByteFormat.string(viewModel.lastCleanupMeasuredBytes)) freed"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(okCount > 0 ? "Space back." : "Nothing cleaned.")
                        .font(Theme.headingFont(size: 40))
                        .foregroundColor(Theme.notes[0].fg)
                    Text(headline)
                        .font(Theme.headingFont(size: 46))
                        .monospacedDigit()
                        .foregroundColor(Theme.current.isDark ? Theme.notes[0].fg : Theme.accent)
                    if viewModel.lastCleanupUsedTrash {
                        Text("Empty the Trash to free the space.")
                            .font(Theme.bodyFont(size: 13))
                            .foregroundColor(Theme.notes[0].fg.opacity(0.85))
                    }
                }
                Spacer()
                Stamp(text: okCount == results.count ? "Done" : "Partly done",
                      color: Theme.current.stampOnNoteA(success: okCount == results.count),
                      angle: -10, size: 32)
                    .padding(.trailing, 16)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .paper(Theme.notes[0].bg, seed: 88, depth: 5)
            .overlay(Tape(color: Theme.current.tapeB, width: 80, angle: -8).offset(x: 30, y: -8), alignment: .topLeading)

            Text("What happened")
                .font(Theme.headingFont(size: 26))
                .foregroundColor(Theme.ink)

            VStack(spacing: 8) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, res in
                    HStack(spacing: 14) {
                        Image(systemName: res.isSuccess ? "checkmark" : "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(res.isSuccess ? Theme.accent : Theme.danger)
                        Text(res.path)
                            .font(Theme.bodyFont(size: 13))
                            .foregroundColor(Theme.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(res.status)
                            .font(Theme.bodyFont(size: 13))
                            .foregroundColor(res.isSuccess ? Theme.ink : Theme.danger)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .paper(Theme.surface, seed: 120 + index, depth: 2, shadow: false)
                }
            }

            HStack(alignment: .center) {
                if !viewModel.lastCleanupKept.isEmpty {
                    Text("Kept: \(viewModel.lastCleanupKept.joined(separator: ", ")).")
                        .font(Theme.bodyFont(size: 12))
                        .foregroundColor(Theme.muted)
                        .lineLimit(2)
                }
                Spacer()
                Button("Done") { viewModel.cleanupResults = [] }
                    .buttonStyle(ZineButtonStyle(kind: .primary, size: 16))
            }
        }
    }
}
