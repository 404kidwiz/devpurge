import XCTest
import SwiftUI
@testable import DevPurge

/// Palette checks that always run, plus optional screenshots of every palette.
/// Set DEVPURGE_SNAPSHOT_DIR to a folder to write PNGs for visual review.
@MainActor
final class PaletteSnapshotTests: XCTestCase {

    /// Body text and button labels must stay readable in every palette (WCAG AA).
    func testEveryPaletteMeetsContrast() {
        for id in PaletteID.allCases {
            let p = id.palette
            let pairs: [(String, Color, Color, Double)] = [
                ("ink/background", p.ink, p.background, 7),
                ("ink/surface", p.ink, p.surface, 7),
                ("muted/background", p.muted, p.background, 4.5),
                ("onPrimary/primary", p.onPrimary, p.primary, 4.5),
                ("onAccent/accent", p.onAccent, p.accent, 4.5),
                ("onNoteA/noteA", p.onNoteA, p.noteA, 4.5),
                ("onNoteB/noteB", p.onNoteB, p.noteB, 4.5),
                ("onNoteC/noteC", p.onNoteC, p.noteC, 4.5),
                ("accent/surface (stamps)", p.accent, p.surface, 3),
                ("danger/surface (stamps)", p.danger, p.surface, 3),
            ]
            for (name, fg, bg, minimum) in pairs {
                let ratio = contrast(fg, bg)
                XCTAssertGreaterThanOrEqual(ratio, minimum, "\(id.title) \(name) is \(String(format: "%.2f", ratio)):1")
            }
        }
    }

    func testPalettesAreDistinctAndSplitLightDark() {
        XCTAssertEqual(PaletteID.allCases.filter { $0.palette.isDark }.count, 2)
        XCTAssertEqual(PaletteID.allCases.filter { !$0.palette.isDark }.count, 2)
        let primaries = Set(PaletteID.allCases.map { hex($0.palette.primary) })
        XCTAssertEqual(primaries.count, PaletteID.allCases.count)
    }

    func testWritesSnapshotsWhenRequested() throws {
        guard let dir = ProcessInfo.processInfo.environment["DEVPURGE_SNAPSHOT_DIR"] else {
            throw XCTSkip("Set DEVPURGE_SNAPSHOT_DIR to write palette screenshots")
        }
        let out = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        FontRegistry.ensureRegistered()

        let vm = DevPurgeViewModel()
        vm.diskSpace = DiskSpace(total: 994_660_000_000, free: 138_290_000_000)
        // Marketing renders set DEVPURGE_SNAPSHOT_HOME so real usernames never ship in images.
        let home = ProcessInfo.processInfo.environment["DEVPURGE_SNAPSHOT_HOME"] ?? NSHomeDirectory()
        vm.targets = [
            Target(id: "a", path: "\(home)/Library/Developer/Xcode/DerivedData", category: "review", status: .eligible, reason: "Rebuilt automatically by Xcode", sizeBytes: 18_400_000_000),
            Target(id: "b", path: "\(home)/.npm/_cacache", category: "oldstores", status: .eligible, reason: "npm downloads it again on demand", sizeBytes: 7_200_000_000),
            Target(id: "c", path: "\(home)/.cargo/registry", category: "oldstores", status: .eligible, reason: "Cargo refetches crates", sizeBytes: 5_900_000_000),
            Target(id: "d", path: "\(home)/Library/Caches/Homebrew", category: "installers", status: .eligible, reason: "Old bottles and downloads", sizeBytes: 3_100_000_000),
            Target(id: "e", path: "\(home)/.gradle/caches", category: "oldstores", status: .inUse, reason: "A Gradle daemon is running", sizeBytes: 2_000_000_000),
        ]
        vm.selectedTargetIDs = ["a", "b", "c"]
        vm.scannedAt = Date()
        vm.rescueMode = true

        for id in PaletteID.allCases {
            ThemeStore.shared.id = id
            try render(ContentView(viewModel: vm).frame(width: 1020, height: 740), to: out.appendingPathComponent("\(id.rawValue)-dashboard.png"), dark: id.palette.isDark)
            try render(ReviewModalView(viewModel: vm), to: out.appendingPathComponent("\(id.rawValue)-review.png"), dark: id.palette.isDark)
            try render(LicenseActivationView(), to: out.appendingPathComponent("\(id.rawValue)-license.png"), dark: id.palette.isDark)
            try render(MenuBarPopoverView(viewModel: vm), to: out.appendingPathComponent("\(id.rawValue)-popover.png"), dark: id.palette.isDark)
        }

        let done = DevPurgeViewModel()
        done.diskSpace = vm.diskSpace
        done.cleanupResults = [
            CleanupResult(path: "~/Library/Developer/Xcode/DerivedData", status: "moved to Trash", isSuccess: true),
            CleanupResult(path: "~/.npm/_cacache", status: "moved to Trash", isSuccess: true),
            CleanupResult(path: "~/.cargo/registry", status: "moved to Trash", isSuccess: true),
        ]
        done.lastCleanupStoredBytes = 31_500_000_000
        done.lastCleanupUsedTrash = true
        done.lastCleanupKept = ["Gradle Caches (in use)", "Homebrew Cache (not selected)"]
        for id in PaletteID.allCases {
            ThemeStore.shared.id = id
            try render(ResultsView(viewModel: done).padding(30).frame(width: 1020).background(Theme.background),
                       to: out.appendingPathComponent("\(id.rawValue)-done.png"), dark: id.palette.isDark)
        }
        ThemeStore.shared.id = .zine
    }

    // MARK: helpers

    /// Hosts the view in an off-screen window so scroll views and AppKit
    /// controls draw exactly as they do in the app.
    private func render<V: View>(_ view: V, to url: URL, dark: Bool) throws {
        let host = NSHostingView(rootView: view.environment(\.colorScheme, dark ? .dark : .light))
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: NSSize(width: max(size.width, 10), height: max(size.height, 10)))
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            XCTFail("Could not render \(url.lastPathComponent)"); return
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("Could not encode \(url.lastPathComponent)"); return
        }
        try png.write(to: url)
    }

    private func components(_ c: Color) -> (Double, Double, Double) {
        let ns = NSColor(c).usingColorSpace(.sRGB)!
        return (Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent))
    }

    private func luminance(_ c: Color) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        let (r, g, b) = components(c)
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private func contrast(_ a: Color, _ b: Color) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func hex(_ c: Color) -> String {
        let (r, g, b) = components(c)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
