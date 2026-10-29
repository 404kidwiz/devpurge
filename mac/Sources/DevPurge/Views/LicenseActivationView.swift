import SwiftUI

public struct LicenseActivationView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var inputKey: String = ""
    @State private var isLoading: Bool = false
    @State private var message: String = ""
    @State private var isError: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LICENSE PASS")
                        .font(Theme.monoFont(size: 11))
                        .tracking(1.4)
                        .foregroundColor(Theme.muted)

                    Text("Unlock DevPurge.")
                        .font(Theme.headingFont(size: 34))
                        .foregroundColor(Theme.ink)
                }
                Spacer()
                Stamp(
                    text: licenseManager.status.isActive ? "Active" : "Trial",
                    color: licenseManager.status.isActive ? Theme.accent : Theme.primary,
                    angle: -5,
                    size: 16
                )
                .padding(.top, 6)
            }

            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundColor(Theme.ink.opacity(0.5))
                .frame(height: 1)

            if case .active(let key, let name) = licenseManager.status {
                // Active State
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Theme.notes[0].fg)
                            .font(.system(size: 20, weight: .bold))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("DevPurge is Activated")
                                .font(Theme.headingFont(size: 18))
                                .foregroundColor(Theme.notes[0].fg)

                            if let customer = name {
                                Text("Registered to: \(customer)")
                                    .font(Theme.bodyFont(size: 12))
                                    .foregroundColor(Theme.notes[0].fg.opacity(0.85))
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paper(Theme.notes[0].bg, seed: 61, depth: 2.5, shadow: false)
                    .rotationEffect(.degrees(-0.8))

                    Text("Key: ••••••••••••\(key.suffix(4))")
                        .font(Theme.monoFont(size: 13))
                        .foregroundColor(Theme.muted)

                    if !message.isEmpty {
                        Text(message)
                            .font(Theme.bodyFont(size: 12))
                            .foregroundColor(isError ? Theme.danger : Theme.accent)
                    }

                    HStack {
                        Button("Deactivate License") {
                            Task {
                                message = await licenseManager.deactivate()
                                isError = false
                            }
                        }
                        .buttonStyle(.plain)
                        .font(Theme.bodyFont(size: 13))
                        .foregroundColor(Theme.danger)

                        Spacer()

                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(ZineButtonStyle(kind: .primary, size: 16))
                    }
                    .padding(.top, 4)
                }
            } else {
                // Unactivated Input State
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text(licenseManager.badgeText)
                            .font(Theme.headingFont(size: 14))
                            .foregroundColor(Theme.notes[0].fg)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .paper(Theme.notes[0].bg, seed: 63, depth: 2, shadow: false)
                            .rotationEffect(.degrees(-1))
                        Text("Scanning is always free.")
                            .font(Theme.bodyFont(size: 13))
                            .foregroundColor(Theme.muted)
                    }

                    Text("Enter the license key from your Lemon Squeezy receipt to unlock unlimited cleanups on up to 2 Macs:")
                        .font(Theme.bodyFont(size: 13))
                        .foregroundColor(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        TextField("XXXXXX-XXXXXX-XXXXXX-XXXXXX", text: $inputKey)
                            .textFieldStyle(.plain)
                            .font(Theme.monoFont(size: 14))
                            .foregroundColor(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.background))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Theme.ink.opacity(0.55), lineWidth: 1.5)
                            )

                        Button(action: activate) {
                            HStack(spacing: 6) {
                                if isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(isLoading ? "Verifying…" : "Activate")
                            }
                        }
                        .buttonStyle(ZineButtonStyle(kind: .primary, size: 16))
                        .disabled(inputKey.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(Theme.bodyFont(size: 12))
                            .foregroundColor(isError ? Theme.danger : Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .center) {
                        Button(action: {
                            if let url = licenseManager.config.checkoutURL {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("Need a license? Get one ($19) ↗")
                                .font(Theme.bodyFont(size: 13))
                                .foregroundColor(Theme.accent)
                                .underline()
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(ZineButtonStyle(kind: .secondary, size: 15))
                        .keyboardShortcut(.cancelAction)
                    }
                    .padding(.top, 6)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
        .padding(.bottom, 36)
        .frame(width: 500)
        .background(
            TornShape(seed: 19, depth: 5, bottomOnly: true)
                .fill(Theme.surface)
                .overlay(TornShape(seed: 19, depth: 5, bottomOnly: true).fill(PaperGrain.image).opacity(0.12).blendMode(.multiply))
        )
        .overlay(Tape(color: Theme.current.tapeB, width: 110, angle: -2.5).offset(y: -4), alignment: .top)
        .padding(14)
        .background(Theme.background)
    }

    private func activate() {
        isLoading = true
        message = ""
        isError = false

        Task {
            let result = await licenseManager.activate(key: inputKey)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success(let msg):
                    message = msg
                    isError = false
                case .failure(let err):
                    message = err.localizedDescription
                    isError = true
                }
            }
        }
    }
}
