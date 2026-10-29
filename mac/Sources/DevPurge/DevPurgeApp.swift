import SwiftUI

@main
struct DevPurgeApp: App {
    @StateObject private var viewModel = DevPurgeViewModel()
    @ObservedObject private var themeStore = ThemeStore.shared

    init() {
        FontRegistry.ensureRegistered()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 680, minHeight: 540)
                .themed()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1020, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Palette") {
                Picker("Palette", selection: $themeStore.id) {
                    ForEach(PaletteID.allCases) { id in
                        Text("\(id.title) — \(id.subtitle)").tag(id)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            CommandMenu("Scan") {
                Button("Scan Storage") {
                    viewModel.scan()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(viewModel.isScanning || viewModel.isCleaning)

                Button("Scan & Select Safe Locations") {
                    viewModel.scanAndSelectSafe()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(viewModel.isScanning || viewModel.isCleaning)

                Button("Add Project Folder to Scan...") {
                    viewModel.chooseProjectFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(viewModel.isScanning || viewModel.isCleaning)

                Divider()

                Button("Select All Safe Locations") {
                    viewModel.selectAllEligible()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(viewModel.eligibleCount == 0)

                Button("Clear Selection") {
                    viewModel.deselectAll()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(viewModel.selectedTargetIDs.isEmpty)

                Divider()

                Button("Copy Storage Report") {
                    viewModel.copyScanReportToClipboard()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(viewModel.targets.isEmpty)
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    if let url = URL(string: "https://devpurge.com/releases") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Manage License...") {
                    viewModel.isLicenseSheetPresented = true
                }
            }
        }

        // macOS Menu Bar Companion
        MenuBarExtra(
            "DevPurge",
            systemImage: viewModel.isLowDiskSpace ? "exclamationmark.triangle.fill" : "sparkles"
        ) {
            MenuBarPopoverView(viewModel: viewModel)
                .themed()
        }
        .menuBarExtraStyle(.window)

        Settings {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Palette")
                        .font(Theme.headingFont(size: 24))
                        .foregroundColor(Theme.ink)
                    Text("Two light and two dark looks. Your choice is saved on this Mac.")
                        .font(Theme.bodyFont(size: 12))
                        .foregroundColor(Theme.muted)
                    PalettePicker()
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Disk & Project Guardrails")
                        .font(Theme.headingFont(size: 20))
                        .foregroundColor(Theme.ink)

                    HStack {
                        Text("Low-disk alert threshold:")
                            .font(Theme.bodyFont(size: 12))
                            .foregroundColor(Theme.ink)
                        Spacer()
                        Picker("Low-disk alert", selection: Binding(
                            get: { viewModel.config.lowDiskAlertThresholdGB },
                            set: { viewModel.updateLowDiskThresholdGB($0) }
                        )) {
                            Text("Off").tag(0)
                            Text("15 GB").tag(15)
                            Text("25 GB").tag(25)
                            Text("50 GB").tag(50)
                        }
                        .labelsHidden()
                        .frame(width: 110)
                    }

                    HStack {
                        Text("Stale project idle window:")
                            .font(Theme.bodyFont(size: 12))
                            .foregroundColor(Theme.ink)
                        Spacer()
                        Picker("Stale project idle window", selection: Binding(
                            get: { viewModel.config.staleProjectDays },
                            set: { viewModel.updateStaleProjectDays($0) }
                        )) {
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                        }
                        .labelsHidden()
                        .frame(width: 110)
                    }
                }
            }
            .padding(24)
            .frame(width: 440)
            .background(Theme.background)
            .themed()
        }
    }
}
