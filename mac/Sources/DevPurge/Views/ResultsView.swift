import SwiftUI

public struct ResultsView: View {
    let results: [CleanupResult]

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LAST CLEANUP")
                    .font(Theme.monoFont(size: 11))
                    .tracking(1.4)
                    .foregroundColor(Theme.dynamicMuted)

                Text("What happened")
                    .font(Theme.headingFont(size: 18))
                    .foregroundColor(Theme.dynamicInk)
            }

            VStack(spacing: 0) {
                ForEach(results) { res in
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: res.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(res.isSuccess ? Theme.dynamicAccent : Theme.dynamicRed)
                            .font(.system(size: 14))

                        Text(res.path)
                            .font(Theme.monoFont(size: 11))
                            .foregroundColor(Theme.dynamicInk)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Text(res.status)
                            .font(Theme.bodyFont(size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(res.isSuccess ? Theme.dynamicAccent : Theme.dynamicRed)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)

                    Divider()
                        .background(Theme.dynamicLine)
                }
            }
            .background(Theme.dynamicSurface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.dynamicLine, lineWidth: 1)
            )
        }
    }
}
