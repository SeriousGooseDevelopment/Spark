import SwiftUI
import UIKit

// MARK: - Colors lifted from the design

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum SK {
    // Surfaces
    static let canvas = Color(hex: 0xEDF0F4)
    static let card = Color.white
    static let chip = Color(hex: 0xF4F6FB)
    static let chipBlue = Color(hex: 0xEEF1FA)
    static let sheetRow = Color(hex: 0xF5F7FB)
    static let shelf = Color(hex: 0xF1F2F4)

    // Ink
    static let ink = Color(hex: 0x111318)
    static let inkStrong = Color(hex: 0x0D0D0F)
    static let ink2 = Color(hex: 0x7A8090)
    static let ink3 = Color(hex: 0x8A909C)
    static let ink4 = Color(hex: 0x9AA0AC)
    static let ink5 = Color(hex: 0xA2A8B4)

    // Accent + status
    static let accent = Color(hex: 0x4A6DE0)
    static let danger = Color(hex: 0xE0574F)
    static let green = Color(hex: 0x4CC98A)
    static let toastCheck = Color(hex: 0x7FE0AC)

    // Lines
    static let separator = Color(hex: 0xF1F2F5)
    static let separatorSoft = Color(hex: 0xF3F4F7)
    static let pickerSeparator = Color(hex: 0xEBEEF4)
    static let track = Color(hex: 0xDEE1E8)
    static let barTrack = Color(hex: 0xEEF1F6)
    static let chevron = Color(hex: 0xC8CCD4)
    static let chevronStrong = Color(hex: 0xC3C7D0)
    static let grabber = Color(hex: 0xDCDFE6)

    // Tab bar
    static let tabInactiveIcon = Color(hex: 0xD9DBDF)
    static let tabInactiveLabel = Color(hex: 0xB7BBC1)

    /// Header band behind Blocking / Parental / Menu and the pushed detail screens.
    static let headerGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x5A79D8), location: 0),
            .init(color: Color(hex: 0x6B87D8), location: 0.55),
            .init(color: Color(hex: 0x7D98D9), location: 1),
        ],
        startPoint: .top, endPoint: .bottom
    )

    /// The full-bleed Home wash — indigo at the top fading to the canvas grey.
    static let homeGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x5A79D8), location: 0.00),
            .init(color: Color(hex: 0x6382D7), location: 0.10),
            .init(color: Color(hex: 0x7795D5), location: 0.20),
            .init(color: Color(hex: 0x85A2D4), location: 0.29),
            .init(color: Color(hex: 0x91AFD3), location: 0.38),
            .init(color: Color(hex: 0xA6BBDA), location: 0.48),
            .init(color: Color(hex: 0xBECDE0), location: 0.60),
            .init(color: Color(hex: 0xCBD6E3), location: 0.70),
            .init(color: Color(hex: 0xD3DBE5), location: 0.80),
            .init(color: Color(hex: 0xD7DDE6), location: 0.90),
            .init(color: Color(hex: 0xDADFE7), location: 1.00),
        ],
        startPoint: .top, endPoint: .bottom
    )

    // Metrics that several screens share
    static let tabBarHeight: CGFloat = 96
    static let panelCornerRadius: CGFloat = 28
}

// MARK: - Shadows

extension View {
    /// The two-part card shadow used on every raised surface in the design.
    func cardShadow() -> some View {
        self
            .shadow(color: Color(hex: 0x1C2C5A, opacity: 0.05), radius: 1, x: 0, y: 1)
            .shadow(color: Color(hex: 0x1C2C5A, opacity: 0.05), radius: 11, x: 0, y: 10)
    }

    /// The lighter single shadow used on device cards and inline buttons.
    func softShadow() -> some View {
        shadow(color: Color(hex: 0x1C2C5A, opacity: 0.06), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Typography

/// Plus Jakarta Sans ships as a single variable font, so weights come from the
/// `wght` axis rather than separate faces. Falls back to the system face if the
/// font failed to register.
enum SKFont {
    private static let familyRegistered: Bool = {
        UIFont.familyNames.contains("Plus Jakarta Sans")
    }()

    private static let wghtAxis = 0x77676874 // 'wght'

    static func face(_ size: CGFloat, _ weight: CGFloat) -> Font {
        guard familyRegistered else {
            return .system(size: size, weight: systemWeight(weight))
        }
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "PlusJakartaSans-Regular",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: weight],
        ])
        return Font(UIFont(descriptor: descriptor, size: size))
    }

    private static func systemWeight(_ w: CGFloat) -> Font.Weight {
        switch w {
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        case ..<750: return .bold
        default: return .heavy
        }
    }

    static func regular(_ size: CGFloat) -> Font { face(size, 400) }
    static func medium(_ size: CGFloat) -> Font { face(size, 500) }
    static func semibold(_ size: CGFloat) -> Font { face(size, 600) }
    static func bold(_ size: CGFloat) -> Font { face(size, 700) }
}

// MARK: - Safe area plumbing
//
// Every screen is laid out against absolute offsets from the top of the display
// (the design is specified that way), so the root reads the insets once and
// hands them down rather than each screen re-deriving them.

private struct SafeTopKey: EnvironmentKey { static let defaultValue: CGFloat = 62 }
private struct SafeBottomKey: EnvironmentKey { static let defaultValue: CGFloat = 34 }

extension EnvironmentValues {
    var safeTop: CGFloat {
        get { self[SafeTopKey.self] }
        set { self[SafeTopKey.self] = newValue }
    }
    var safeBottom: CGFloat {
        get { self[SafeBottomKey.self] }
        set { self[SafeBottomKey.self] = newValue }
    }
}
