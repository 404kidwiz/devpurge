import SwiftUI

@main
struct DevPurgeApp: App {
    @StateObject private var viewModel = DevPurgeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 620, minHeight: 480)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 880, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Scan") {
                Button("Scan Storage") {
                    viewModel.scan()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(viewModel.isScanning || viewModel.isCleaning)
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    // Hook for Sparkle updater / web release check
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
        MenuBarExtra("DevPurge", systemImage: "sparkles") {
            MenuBarPopoverView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
