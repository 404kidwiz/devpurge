import SwiftUI
import AppKit

public struct TargetRowView: View {
    let target: Target
    let isSelected: Bool
    let onToggle: () -> Void
    var onIgnoreCategory: (() -> Void)? = nil

    @State private var isHovered: Bool = false

    public init(
        target: Target,
        isSelected: Bool,
        onToggle: @escaping () -> Void,
        onIgnoreCategory: (() -> Void)? = nil
    ) {
        self.target = target
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onIgnoreCategory = onIgnoreCategory
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(target.status == .eligible ? (isSelected ? Theme.dynamicAccent : Theme.dynamicMuted) : Theme.dynamicLine)
            }
            .buttonStyle(.plain)
            .disabled(target.status != .eligible)
            .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(target.displayName)
                        .font(Theme.headingFont(size: 14))
                        .foregroundColor(Theme.dynamicInk)

                    // Category tag
                    Text(target.category)
                        .font(Theme.monoFont(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.dynamicSoft)
                        .foregroundColor(Theme.dynamicAccent)
                        .cornerRadius(4)

                    // Action buttons on hover
                    HStack(spacing: 6) {
                        Button(action: revealInFinder) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.dynamicMuted)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")

                        Button(action: revealInFinder) {
                            Image(systemName: "eye")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.dynamicMuted)
                        }
                        .buttonStyle(.plain)
                        .help("Preview in Finder")
                    }
                    .opacity(isHovered ? 1.0 : 0.0)
                }

                // Path
                Text(target.path)
                    .font(Theme.monoFont(size: 11))
                    .foregroundColor(Theme.dynamicMuted)
                    .textSelection(.enabled)
                    .lineLimit(2)

                // Reason
                Text(target.reason)
                    .font(Theme.bodyFont(size: 12))
                    .foregroundColor(target.status == .inUse ? Theme.dynamicWarn : Theme.dynamicMuted)
                    .padding(.top, 2)
            }

            Spacer(minLength: 8)

            // Status Badge
            Text(target.status.badgeLabel)
                .font(Theme.bodyFont(size: 11))
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(target.status == .eligible ? Theme.dynamicSoft : Theme.dynamicWarnBg)
                .foregroundColor(target.status == .eligible ? Theme.dynamicAccent : Theme.dynamicWarn)
                .cornerRadius(4)

            // Size
            Text(target.formattedSize)
                .font(Theme.monoFont(size: 13))
                .foregroundColor(Theme.dynamicInk)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(isSelected ? Theme.dynamicSoft.opacity(0.35) : (isHovered ? Theme.dynamicSurface.opacity(0.5) : Color.clear))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            if target.status == .eligible {
                onToggle()
            }
        }
        .contextMenu {
            Button("Reveal in Finder") {
                revealInFinder()
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(target.path, forType: .string)
            }
            Divider()
            Button("Always Ignore '\(target.category)' in Config") {
                onIgnoreCategory?()
            }
        }
    }

    private func revealInFinder() {
        let url = URL(fileURLWithPath: target.path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
