import SwiftUI

public enum Theme {
    // Light / Dark adaptive colors matching DESIGN.md & style.css
    public static let background = Color("Background", bundle: nil)
    public static let surface = Color("Surface", bundle: nil)

    public static let dynamicBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0x20/255.0, green: 0x26/255.0, blue: 0x22/255.0, alpha: 1.0)
            : NSColor(red: 0xf5/255.0, green: 0xf3/255.0, blue: 0xed/255.0, alpha: 1.0)
    }))

    public static let dynamicSurface = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0x2a/255.0, green: 0x32/255.0, blue: 0x2c/255.0, alpha: 1.0)
            : NSColor(red: 0xff/255.0, green: 0xfe/255.0, blue: 0xf9/255.0, alpha: 1.0)
    }))

    public static let dynamicInk = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0xf0/255.0, green: 0xf2/255.0, blue: 0xe9/255.0, alpha: 1.0)
            : NSColor(red: 0x28/255.0, green: 0x2e/255.0, blue: 0x2b/255.0, alpha: 1.0)
    }))

    public static let dynamicMuted = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0xb5/255.0, green: 0xc1/255.0, blue: 0xb5/255.0, alpha: 1.0)
            : NSColor(red: 0x5d/255.0, green: 0x67/255.0, blue: 0x5f/255.0, alpha: 1.0)
    }))

    public static let dynamicLine = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0x49/255.0, green: 0x56/255.0, blue: 0x4b/255.0, alpha: 1.0)
            : NSColor(red: 0xd9/255.0, green: 0xdd/255.0, blue: 0xd3/255.0, alpha: 1.0)
    }))

    public static let dynamicAccent = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0xba/255.0, green: 0xd9/255.0, blue: 0xa9/255.0, alpha: 1.0)
            : NSColor(red: 0x27/255.0, green: 0x59/255.0, blue: 0x41/255.0, alpha: 1.0)
    }))

    public static let dynamicOnAccent = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0x1d/255.0, green: 0x30/255.0, blue: 0x20/255.0, alpha: 1.0)
            : NSColor(red: 0xff/255.0, green: 0xfe/255.0, blue: 0xf9/255.0, alpha: 1.0)
    }))

    public static let dynamicSoft = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0x35/255.0, green: 0x49/255.0, blue: 0x3a/255.0, alpha: 1.0)
            : NSColor(red: 0xe5/255.0, green: 0xed/255.0, blue: 0xdf/255.0, alpha: 1.0)
    }))

    public static let dynamicWarn = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0xf0/255.0, green: 0xcb/255.0, blue: 0x84/255.0, alpha: 1.0)
            : NSColor(red: 0x78/255.0, green: 0x50/255.0, blue: 0x15/255.0, alpha: 1.0)
    }))

    public static let dynamicWarnBg = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0x49/255.0, green: 0x3d/255.0, blue: 0x29/255.0, alpha: 1.0)
            : NSColor(red: 0xfb/255.0, green: 0xef/255.0, blue: 0xd8/255.0, alpha: 1.0)
    }))

    public static let dynamicRed = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0xff/255.0, green: 0xa9/255.0, blue: 0xa1/255.0, alpha: 1.0)
            : NSColor(red: 0x9c/255.0, green: 0x30/255.0, blue: 0x2b/255.0, alpha: 1.0)
    }))

    public static func headingFont(size: CGFloat) -> Font {
        Font.custom("Avenir Next", size: size).weight(.medium)
    }

    public static func bodyFont(size: CGFloat = 14) -> Font {
        Font.custom("Avenir Next", size: size)
    }

    public static func monoFont(size: CGFloat = 12) -> Font {
        Font.custom("Menlo", size: size)
    }
}
