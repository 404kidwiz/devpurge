import SwiftUI
import AppKit
import CoreText

// MARK: - Palettes

/// One complete colour set. Views read semantic roles only, so every palette
/// can use entirely different hues without touching view code.
public struct Palette: Sendable {
    public let isDark: Bool
    public let background: Color   // window paper
    public let surface: Color      // cards, rows, receipt
    public let ink: Color          // primary text
    public let muted: Color        // secondary text
    public let line: Color         // rules, borders
    public let primary: Color      // main call to action
    public let onPrimary: Color
    public let accent: Color       // selection, checkboxes, "safe" stamps
    public let onAccent: Color
    public let noteA: Color, onNoteA: Color   // sticky note 1
    public let noteB: Color, onNoteB: Color   // sticky note 2
    public let noteC: Color, onNoteC: Color   // sticky note 3
    public let danger: Color       // in-use / errors
    public let warn: Color
    public let warnBg: Color
    public let tapeA: Color
    public let tapeB: Color
}

public enum PaletteID: String, CaseIterable, Identifiable, Sendable {
    case zine, citrus, blacklight, ember
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .zine: return "Zine"
        case .citrus: return "Citrus"
        case .blacklight: return "Blacklight"
        case .ember: return "Ember"
        }
    }

    public var subtitle: String {
        switch self {
        case .zine: return "Light · pink, cobalt, yellow"
        case .citrus: return "Light · orange, violet, teal"
        case .blacklight: return "Dark · lime, magenta, cyan"
        case .ember: return "Dark · amber, coral, sage"
        }
    }

    public var palette: Palette {
        switch self {
        case .zine:
            return Palette(
                isDark: false,
                background: .hex(0xF6EFE0), surface: .hex(0xFFFBF2), ink: .hex(0x141414),
                muted: .hex(0x5C5447), line: .hex(0xD8CDB8),
                primary: .hex(0xFF4FA3), onPrimary: .hex(0x141414),
                accent: .hex(0x2B3FE0), onAccent: .hex(0xFFFBF2),
                noteA: .hex(0xFFD21F), onNoteA: .hex(0x141414),
                noteB: .hex(0xFF4FA3), onNoteB: .hex(0x141414),
                noteC: .hex(0x2B3FE0), onNoteC: .hex(0xFFFBF2),
                danger: .hex(0xB81D24), warn: .hex(0x7A4E00), warnBg: .hex(0xFFEFC2),
                tapeA: .hex(0xFFD21F), tapeB: .hex(0xFF4FA3))
        case .citrus:
            return Palette(
                isDark: false,
                background: .hex(0xEFF3E1), surface: .hex(0xFBFCF4), ink: .hex(0x1B2414),
                muted: .hex(0x55604A), line: .hex(0xC9D2B2),
                primary: .hex(0xFF6A13), onPrimary: .hex(0x1B2414),
                accent: .hex(0x0B7466), onAccent: .hex(0xFBFCF4),
                noteA: .hex(0xB8E35A), onNoteA: .hex(0x1B2414),
                noteB: .hex(0x6A48E0), onNoteB: .hex(0xFBFCF4),
                noteC: .hex(0xFF6A13), onNoteC: .hex(0x1B2414),
                danger: .hex(0xC2185B), warn: .hex(0x7A5200), warnBg: .hex(0xFFE7C2),
                tapeA: .hex(0xB8E35A), tapeB: .hex(0x9C84F5))
        case .blacklight:
            return Palette(
                isDark: true,
                background: .hex(0x0F1016), surface: .hex(0x1B1D28), ink: .hex(0xF2F2EA),
                muted: .hex(0xA4A7BA), line: .hex(0x353949),
                primary: .hex(0xC6FF3D), onPrimary: .hex(0x0F1016),
                accent: .hex(0x39D9FF), onAccent: .hex(0x0F1016),
                noteA: .hex(0xC6FF3D), onNoteA: .hex(0x0F1016),
                noteB: .hex(0xFF5FD2), onNoteB: .hex(0x0F1016),
                noteC: .hex(0x39D9FF), onNoteC: .hex(0x0F1016),
                danger: .hex(0xFF6B6B), warn: .hex(0xFFC857), warnBg: .hex(0x3A2F17),
                tapeA: .hex(0xC6FF3D), tapeB: .hex(0xFF5FD2))
        case .ember:
            return Palette(
                isDark: true,
                background: .hex(0x1D1310), surface: .hex(0x2B1D18), ink: .hex(0xF6E9DA),
                muted: .hex(0xC4AF9C), line: .hex(0x4C352B),
                primary: .hex(0xFFB238), onPrimary: .hex(0x1D1310),
                accent: .hex(0x86CFBA), onAccent: .hex(0x1D1310),
                noteA: .hex(0xFFB238), onNoteA: .hex(0x1D1310),
                noteB: .hex(0xFF7A66), onNoteB: .hex(0x1D1310),
                noteC: .hex(0x86CFBA), onNoteC: .hex(0x1D1310),
                danger: .hex(0xFF7A9A), warn: .hex(0xFFD27A), warnBg: .hex(0x3D2A16),
                tapeA: .hex(0xFFB238), tapeB: .hex(0x86CFBA))
        }
    }
}

/// Holds the chosen palette and persists it. Views that apply `.themed()`
/// rebuild when it changes.
@MainActor
public final class ThemeStore: ObservableObject {
    public static let shared = ThemeStore()
    private static let key = "DevPurge.palette"

    @Published public var id: PaletteID {
        didSet {
            Theme.current = id.palette
            UserDefaults.standard.set(id.rawValue, forKey: Self.key)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key).flatMap(PaletteID.init(rawValue:))
        id = saved ?? .zine
        Theme.current = id.palette
    }
}

// MARK: - Theme tokens

public enum Theme {
    // Read by views during body evaluation; ThemeStore swaps it on the main actor.
    nonisolated(unsafe) public static var current: Palette = PaletteID.zine.palette

    public static var background: Color { current.background }
    public static var surface: Color { current.surface }
    public static var ink: Color { current.ink }
    public static var muted: Color { current.muted }
    public static var line: Color { current.line }
    public static var primary: Color { current.primary }
    public static var onPrimary: Color { current.onPrimary }
    public static var accent: Color { current.accent }
    public static var onAccent: Color { current.onAccent }
    public static var danger: Color { current.danger }
    public static var warn: Color { current.warn }
    public static var warnBg: Color { current.warnBg }
    public static var notes: [(bg: Color, fg: Color)] {
        [(current.noteA, current.onNoteA), (current.noteB, current.onNoteB), (current.noteC, current.onNoteC)]
    }

    // Older token names still used by the license sheet.
    public static var dynamicBackground: Color { current.background }
    public static var dynamicSurface: Color { current.surface }
    public static var dynamicInk: Color { current.ink }
    public static var dynamicMuted: Color { current.muted }
    public static var dynamicLine: Color { current.line }
    public static var dynamicAccent: Color { current.accent }
    public static var dynamicOnAccent: Color { current.onAccent }
    public static var dynamicSoft: Color { current.accent.opacity(current.isDark ? 0.22 : 0.12) }
    public static var dynamicWarn: Color { current.warn }
    public static var dynamicWarnBg: Color { current.warnBg }
    public static var dynamicRed: Color { current.danger }

    /// Chunky poster face for headings and numbers.
    public static func headingFont(size: CGFloat) -> Font {
        FontRegistry.ensureRegistered()
        return Font.custom("Lilita One", size: size)
    }

    /// Typewriter face for body copy.
    public static func bodyFont(size: CGFloat = 14) -> Font {
        FontRegistry.ensureRegistered()
        return Font.custom("Courier Prime", size: size)
    }

    public static func monoFont(size: CGFloat = 12) -> Font {
        FontRegistry.ensureRegistered()
        return Font.custom("Courier Prime", size: size)
    }
}

extension Color {
    static func hex(_ value: UInt32) -> Color {
        Color(.sRGB,
              red: Double((value >> 16) & 0xFF) / 255,
              green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255,
              opacity: 1)
    }
}

// MARK: - Fonts

/// Registers the bundled OFL fonts once. Looks in the app bundle first
/// (Contents/Resources/Fonts), then next to the sources for `swift run`.
enum FontRegistry {
    nonisolated(unsafe) private static var done = false

    static func ensureRegistered() {
        guard !done else { return }
        done = true
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Resources/Fonts")
        ]
        for case let dir? in candidates {
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            let fonts = files.filter { $0.pathExtension.lowercased() == "ttf" }
            guard !fonts.isEmpty else { continue }
            for url in fonts {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
            return
        }
    }
}

// MARK: - Paper components

/// Applies the chosen palette to a view tree and rebuilds it on change.
struct ThemedModifier: ViewModifier {
    @ObservedObject private var store = ThemeStore.shared

    func body(content: Content) -> some View {
        content
            .id(store.id)
            .preferredColorScheme(store.id.palette.isDark ? .dark : .light)
            .tint(Theme.accent)
    }
}

extension View {
    func themed() -> some View { modifier(ThemedModifier()) }

    /// Rectangle with slightly ragged, deterministic edges, like cut paper.
    func paper(_ color: Color, seed: Int = 1, depth: CGFloat = 3, shadow: Bool = true) -> some View {
        background(
            TornShape(seed: seed, depth: depth)
                .fill(color)
                .overlay(TornShape(seed: seed, depth: depth).fill(PaperGrain.image).opacity(Theme.current.isDark ? 0.10 : 0.16).blendMode(.multiply))
                .shadow(color: .black.opacity(shadow ? (Theme.current.isDark ? 0.45 : 0.14) : 0), radius: 6, x: 0, y: 4)
        )
    }
}

/// Paper shape with jittered edges. Same seed always yields the same tear.
struct TornShape: Shape {
    var seed: Int
    var depth: CGFloat = 3
    var bottomOnly = false

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: UInt64(seed &* 7919 &+ 17))
        var p = Path()
        let step: CGFloat = 14
        let d = depth
        func j() -> CGFloat { CGFloat(rng.next()) * d }

        p.move(to: CGPoint(x: rect.minX, y: rect.minY + (bottomOnly ? 0 : j())))
        var x = rect.minX
        while x < rect.maxX {
            x = min(rect.maxX, x + step)
            p.addLine(to: CGPoint(x: x, y: rect.minY + (bottomOnly ? 0 : j())))
        }
        var y = rect.minY
        while y < rect.maxY {
            y = min(rect.maxY, y + step * 2)
            p.addLine(to: CGPoint(x: rect.maxX - (bottomOnly ? 0 : j() * 0.6), y: y))
        }
        x = rect.maxX
        let bottomDepth = bottomOnly ? d * 2.4 : d
        var up = false
        while x > rect.minX {
            x = max(rect.minX, x - (bottomOnly ? 9 : step))
            up.toggle()
            let off = bottomOnly ? (up ? bottomDepth : 0) : CGFloat(rng.next()) * bottomDepth
            p.addLine(to: CGPoint(x: x, y: rect.maxY - off))
        }
        y = rect.maxY
        while y > rect.minY {
            y = max(rect.minY, y - step * 2)
            p.addLine(to: CGPoint(x: rect.minX + (bottomOnly ? 0 : j() * 0.6), y: y))
        }
        p.closeSubpath()
        return p
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 10_000) / 10_000
    }
}

/// Tiled fibre noise, generated once, multiplied over paper surfaces.
enum PaperGrain {
    static let image: ImagePaint = {
        let size = 96
        var rng = SeededRandom(seed: 42)
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        for i in 0..<(size * size) {
            let v = UInt8(200 + Int(rng.next() * 55))
            bytes[i * 4] = v; bytes[i * 4 + 1] = v; bytes[i * 4 + 2] = v; bytes[i * 4 + 3] = 255
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: &bytes, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let cg = ctx.makeImage()!
        return ImagePaint(image: Image(decorative: cg, scale: 2))
    }()
}

/// Strip of washi tape with notched ends.
struct Tape: View {
    var color: Color
    var width: CGFloat = 70
    var angle: Double = -4

    var body: some View {
        TapeShape()
            .fill(color.opacity(Theme.current.isDark ? 0.85 : 0.78))
            .frame(width: width, height: 18)
            .rotationEffect(.degrees(angle))
            .accessibilityHidden(true)
    }
}

struct TapeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let n = 4, h = r.height / CGFloat(n)
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        for i in 0..<n {
            p.addLine(to: CGPoint(x: r.maxX - (i % 2 == 0 ? 4 : 0), y: r.minY + h * CGFloat(i) + h / 2))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        for i in (0..<n).reversed() {
            p.addLine(to: CGPoint(x: r.minX + (i % 2 == 0 ? 4 : 0), y: r.minY + h * CGFloat(i) + h / 2))
        }
        p.closeSubpath()
        return p
    }
}

/// Rubber-stamp status label.
struct Stamp: View {
    var text: String
    var color: Color
    var angle: Double = -4
    var size: CGFloat = 15

    var body: some View {
        Text(text.uppercased())
            .font(Theme.headingFont(size: size))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: 2.2))
            .rotationEffect(.degrees(angle))
            .fixedSize()
    }
}

/// Square check mark drawn like a marker tick.
struct ZineCheckbox: View {
    var isOn: Bool
    var isEnabled: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isOn ? Theme.accent : Theme.surface)
            RoundedRectangle(cornerRadius: 4)
                .stroke(isEnabled ? (isOn ? Theme.accent : Theme.ink.opacity(0.55)) : Theme.line, lineWidth: 2)
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Theme.onAccent)
            }
        }
        .frame(width: 22, height: 22)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.15), value: isOn)
    }
}

/// Three short marker dashes, the zine "pop" accent.
struct Dashes: View {
    var color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Capsule().fill(color).frame(width: 18, height: 3.5).rotationEffect(.degrees(-24))
            Capsule().fill(color).frame(width: 22, height: 3.5).rotationEffect(.degrees(-6))
            Capsule().fill(color).frame(width: 18, height: 3.5).rotationEffect(.degrees(14))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

struct ZineButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary
    var size: CGFloat = 17

    func makeBody(configuration: Configuration) -> some View {
        ZineButtonBody(configuration: configuration, kind: kind, size: size)
    }
}

private struct ZineButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: ZineButtonStyle.Kind
    let size: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(Theme.headingFont(size: size))
            .padding(.horizontal, size * 1.15)
            .padding(.vertical, size * 0.55)
            .foregroundColor(kind == .primary ? Theme.onPrimary : Theme.ink)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(kind == .primary ? Theme.primary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(kind == .primary ? Color.clear : Theme.ink.opacity(0.75), lineWidth: 2)
            )
            .shadow(color: Theme.ink.opacity(hovering && isEnabled ? 0.9 : 0), radius: 0, x: hovering ? 3 : 0, y: hovering ? 3 : 0)
            .offset(x: hovering && isEnabled ? -1.5 : 0, y: hovering && isEnabled ? -1.5 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.14), value: hovering)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering = $0 }
            .contentShape(Rectangle())
    }
}

// MARK: - Palette picker

/// Swatch picker used in Settings and the menu-bar popover.
struct PalettePicker: View {
    @ObservedObject private var store = ThemeStore.shared
    var compact = false

    var body: some View {
        if compact {
            HStack(spacing: 8) {
                ForEach(PaletteID.allCases) { id in
                    Button { store.id = id } label: { swatch(id, size: 22) }
                        .buttonStyle(.plain)
                        .help("\(id.title) · \(id.subtitle)")
                        .accessibilityLabel("\(id.title) palette")
                        .accessibilityAddTraits(store.id == id ? .isSelected : [])
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(PaletteID.allCases) { id in
                    Button { store.id = id } label: {
                        HStack(spacing: 14) {
                            swatch(id, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(id.title).font(Theme.headingFont(size: 18)).foregroundColor(Theme.ink)
                                Text(id.subtitle).font(Theme.bodyFont(size: 12)).foregroundColor(Theme.muted)
                            }
                            Spacer()
                            if store.id == id {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.accent)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(store.id == id ? Theme.accent.opacity(0.12) : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.id == id ? .isSelected : [])
                }
            }
        }
    }

    private func swatch(_ id: PaletteID, size: CGFloat) -> some View {
        let p = id.palette
        return ZStack {
            Circle().fill(p.background)
            Circle().trim(from: 0, to: 0.34).stroke(p.noteA, lineWidth: size * 0.28).rotationEffect(.degrees(-90))
            Circle().trim(from: 0.34, to: 0.67).stroke(p.noteB, lineWidth: size * 0.28).rotationEffect(.degrees(-90))
            Circle().trim(from: 0.67, to: 1).stroke(p.noteC, lineWidth: size * 0.28).rotationEffect(.degrees(-90))
        }
        .frame(width: size * 0.72, height: size * 0.72)
        .frame(width: size, height: size)
        .background(Circle().fill(p.background))
        .overlay(Circle().stroke(store.id == id ? Theme.ink : Theme.line, lineWidth: store.id == id ? 2.5 : 1))
    }
}
