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
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("LICENSE ACTIVATION")
                    .font(Theme.monoFont(size: 11))
                    .tracking(1.4)
                    .foregroundColor(Theme.dynamicMuted)

                Text("Unlock DevPurge")
                    .font(Theme.headingFont(size: 22))
                    .foregroundColor(Theme.dynamicInk)
            }

            if case .active(let key, let name) = licenseManager.status {
                // Active State
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Theme.dynamicAccent)
                            .font(.system(size: 18))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("DevPurge is Activated")
                                .font(Theme.headingFont(size: 15))
                                .foregroundColor(Theme.dynamicInk)

                            if let customer = name {
                                Text("Registered to: \(customer)")
                                    .font(Theme.bodyFont(size: 12))
                                    .foregroundColor(Theme.dynamicMuted)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.dynamicSoft)
                    .cornerRadius(8)

                    Text("Key: ••••••••••••\(key.suffix(4))")
                        .font(Theme.monoFont(size: 12))
                        .foregroundColor(Theme.dynamicMuted)

                    HStack {
                        Button("Deactivate License") {
                            Task {
                                message = await licenseManager.deactivate()
                                isError = false
                            }
                        }
                        .buttonStyle(.plain)
                        .font(Theme.bodyFont(size: 12))
                        .foregroundColor(Theme.dynamicRed)

                        Spacer()

                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.plain)
                        .font(Theme.headingFont(size: 13))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.dynamicAccent)
                        .foregroundColor(Theme.dynamicOnAccent)
                        .cornerRadius(6)
                    }
                }
            } else {
                // Unactivated Input State
                VStack(alignment: .leading, spacing: 14) {
                    Text("Scanning is always free. Enter the license key from your Lemon Squeezy receipt to unlock cleanup:")
                        .font(Theme.bodyFont(size: 13))
                        .foregroundColor(Theme.dynamicInk)

                    HStack(spacing: 8) {
                        TextField("XXXXXX-XXXXXX-XXXXXX-XXXXXX", text: $inputKey)
                            .textFieldStyle(.plain)
                            .font(Theme.monoFont(size: 13))
                            .padding(10)
                            .background(Theme.dynamicSurface)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.dynamicLine, lineWidth: 1)
                            )

                        Button(action: activate) {
                            HStack(spacing: 6) {
                                if isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(isLoading ? "Verifying..." : "Activate")
                                    .font(Theme.headingFont(size: 13))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Theme.dynamicAccent)
                            .foregroundColor(Theme.dynamicOnAccent)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputKey.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(Theme.bodyFont(size: 12))
                            .foregroundColor(isError ? Theme.dynamicRed : Theme.dynamicAccent)
                    }

                    HStack {
                        Button("Need a license? Purchase here ↗") {
                            if let url = licenseManager.config.checkoutURL {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(Theme.bodyFont(size: 12))
                        .buttonStyle(.link)

                        Spacer()

                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.plain)
                        .font(Theme.bodyFont(size: 13))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.clear)
                        .foregroundColor(Theme.dynamicInk)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.dynamicLine, lineWidth: 1)
                        )
                    }
                    .padding(.top, 6)
                }
            }
        }
        .padding(28)
        .frame(width: 480)
        .background(Theme.dynamicBackground)
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
