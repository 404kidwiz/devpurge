import SwiftUI
import AppKit

/// One scanned location, drawn as a strip of paper with a status stamp.
public struct TargetRowView: View {
    let target: Target
    let isSelected: Bool
    var isPruning: Bool = false
    var seed: Int = 1
    let onToggle: () -> Void
    var onIgnoreCategory: (() -> Void)? = nil
    var onNativePrune: (() -> Void)? = nil

    @State private var isHovered = false
    @State private var copiedCLI = false

    public init(
        target: Target,
        isSelected: Bool,
        isPruning: Bool = false,
        seed: Int = 1,
        onToggle: @escaping () -> Void,
        onIgnoreCategory: (() -> Void)? = nil,
        onNativePrune: (() -> Void)? = nil
    ) {
        self.target = target
        self.isSelected = isSelected
        self.isPruning = isPruning
        self.seed = seed
        self.onToggle = onToggle
        self.onIgnoreCategory = onIgnoreCategory
        self.onNativePrune = onNativePrune
    }

    private var eligible: Bool { target.status == .eligible }

    public var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZineCheckbox(isOn: isSelected, isEnabled: eligible)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(target.friendlyTitle)
                        .font(Theme.headingFont(size: 18))
                        .foregroundColor(Theme.ink)
                    Text(target.category)
                        .font(Theme.bodyFont(size: 11))
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    HStack(spacing: 8) {
                        Button(action: revealInFinder) { Image(systemName: "folder") }
                            .help("Reveal in Finder")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
                    .opacity(isHovered ? 1 : 0.45)
                }
                Text(target.path)
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(Theme.muted)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !eligible || isHovered {
                    Text(target.reason)
                        .font(Theme.bodyFont(size: 12))
                        .foregroundColor(target.status == .inUse ? Theme.danger : Theme.muted)
                }
                if target.status == .review && (target.nativePruneSpec != nil || target.cliSuggestion != nil) {
                    reviewActionPills
                }
            }

            Spacer(minLength: 12)

            Text(target.formattedSize)
                .font(Theme.bodyFont(size: 17))
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(Theme.ink)
                .frame(minWidth: 86, alignment: .trailing)

            stamp
                .frame(width: 150, alignment: .center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .paper(isSelected ? Theme.surface : Theme.surface.opacity(Theme.current.isDark ? 0.75 : 0.85), seed: seed, depth: 2, shadow: isHovered || isSelected)
        .opacity(eligible ? 1 : 0.78)
        .offset(y: isHovered && eligible ? -2 : 0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { if eligible { onToggle() } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(eligible ? .isButton : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAction { if eligible { onToggle() } }
        .contextMenu {
            Button("Reveal in Finder") { revealInFinder() }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(target.path, forType: .string)
            }
            if let cli = target.cliSuggestion {
                Button("Copy CLI Command (\(cli))") { copyCLI(cli) }
            }
            if let spec = target.nativePruneSpec, let onNativePrune = onNativePrune, target.status == .review {
                Button(spec.label) { onNativePrune() }
            }
            Divider()
            Button("Always Ignore '\(target.category)' in Config") { onIgnoreCategory?() }
        }
    }

    @ViewBuilder
    private var reviewActionPills: some View {
        HStack(spacing: 8) {
            if let spec = target.nativePruneSpec, let onNativePrune = onNativePrune {
                Button(action: onNativePrune) {
                    HStack(spacing: 5) {
                        if isPruning {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(isPruning ? "Pruning…" : spec.label)
                            .font(Theme.bodyFont(size: 11))
                            .fontWeight(.bold)
                    }
                    .foregroundColor(Theme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.notes[1].bg.opacity(Theme.current.isDark ? 0.35 : 0.65)))
                    .overlay(Capsule().stroke(Theme.ink.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isPruning)
                .help("Run safe native tool prune without deleting active runtimes")
            }

            if let cli = target.cliSuggestion {
                Button(action: { copyCLI(cli) }) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedCLI ? "checkmark" : "terminal")
                            .font(.system(size: 10, weight: .semibold))
                        Text(copiedCLI ? "Copied!" : "Copy `\(cli)`")
                            .font(Theme.bodyFont(size: 11))
                    }
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Copy CLI command to clipboard")
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var stamp: some View {
        switch target.status {
        case .eligible:
            Stamp(text: "Safe", color: Theme.accent, angle: -4)
        case .inUse:
            Stamp(text: "In use · skipped", color: Theme.danger, angle: -5, size: 13)
        case .review:
            Stamp(text: "Review", color: Theme.warn, angle: -3)
        case .ignored:
            Stamp(text: "Ignored", color: Theme.muted, angle: -3)
        }
    }

    private func copyCLI(_ cli: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cli, forType: .string)
        copiedCLI = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            copiedCLI = false
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: target.path)])
    }
}
