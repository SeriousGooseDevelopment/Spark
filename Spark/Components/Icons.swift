import SwiftUI

/// Icon path data, copied verbatim from the design so the glyphs match exactly.
/// All authored in a 24×24 viewBox unless noted.
enum Icons {
    // Menu and quick-action rows
    static let device = "M7.5 2.6h9a2.4 2.4 0 0 1 2.4 2.4v14a2.4 2.4 0 0 1-2.4 2.4h-9A2.4 2.4 0 0 1 5.1 19V5a2.4 2.4 0 0 1 2.4-2.4z M10.6 18.4h2.8"
    static let lists = "M3.6 6.4h16.8 M6.4 12h11.2 M9.6 17.6h4.8"
    static let shield = "M12 3.2 19 6v6c0 4.2-3 7.4-7 8.8-4-1.4-7-4.6-7-8.8V6z"
    static let help = "M12 3.2a8.8 8.8 0 1 0 0 17.6 8.8 8.8 0 0 0 0-17.6 M9.7 9.4a2.4 2.4 0 0 1 4.7.7c0 1.6-2.3 2-2.3 3.4 M12 17.2v.4"
    static let feedback = "M4.4 5.2h15.2a1.6 1.6 0 0 1 1.6 1.6v8.4a1.6 1.6 0 0 1-1.6 1.6H9.6L5.2 20v-3.2H4.4a1.6 1.6 0 0 1-1.6-1.6V6.8a1.6 1.6 0 0 1 1.6-1.6z"
    static let blockSite = "M12 3.2a8.8 8.8 0 1 0 0 17.6 8.8 8.8 0 0 0 0-17.6 M5.8 5.8l12.4 12.4"
    static let allowSite = "M12 3.2a8.8 8.8 0 1 0 0 17.6 8.8 8.8 0 0 0 0-17.6 M8.2 12.4l2.6 2.6 5-5.6"

    // Tab bar — authored in a 26×26 viewBox
    static let tabHome = "M3.6 11.6 13 3.4l9.4 8.2v8.3a2 2 0 0 1-2 2H5.6a2 2 0 0 1-2-2z M13.9 21.9v-4.2"
    static let tabBlocking = "M22.2 13a9.2 9.2 0 1 0-18.4 0 9.2 9.2 0 0 0 18.4 0 M6.6 6.6l12.8 12.8"
    static let tabParental = "M8 11h10a3.4 3.4 0 0 1 3.4 3.4v4.6a3.4 3.4 0 0 1-3.4 3.4H8a3.4 3.4 0 0 1-3.4-3.4v-4.6A3.4 3.4 0 0 1 8 11z M8.8 11V8.2a4.2 4.2 0 0 1 8.4 0V11"
    static let tabMenu = "M4.4 8h17.2 M4.4 13h17.2 M4.4 18h17.2"

    // Small glyphs
    static let plus = "M8.5 3.4v11.2M2.9 9h11.2"            // 17×17
    static let close = "M1.4 1.4l7.2 7.2M8.6 1.4 1.4 8.6"    // 10×10
    static let check = "M1.6 6.2 5.4 10 13.4 1.8"            // 15×12
    static let backChevron = "M6.5 1.5 1.5 7l5 5.5"          // 8×14
}

/// Small non-square icons need their own viewBox height, which `SVGPathShape`
/// squares off — this wrapper draws them at the right aspect instead.
struct GlyphIcon: View {
    var path: String
    var width: CGFloat
    var height: CGFloat
    var viewBox: CGSize
    var color: Color
    var lineWidth: CGFloat

    var body: some View {
        SVGPathShape(commands: path, viewBox: viewBox)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth * width / viewBox.width,
                                              lineCap: .round, lineJoin: .round))
            .frame(width: width, height: height)
    }
}

extension GlyphIcon {
    static func plus(size: CGFloat = 17, color: Color = SK.accent) -> GlyphIcon {
        GlyphIcon(path: Icons.plus, width: size, height: size,
                  viewBox: CGSize(width: 17, height: 17), color: color, lineWidth: 2)
    }

    static func close(size: CGFloat = 10, color: Color = SK.ink3) -> GlyphIcon {
        GlyphIcon(path: Icons.close, width: size, height: size,
                  viewBox: CGSize(width: 10, height: 10), color: color, lineWidth: 1.8)
    }

    static func check(width: CGFloat = 15, color: Color = SK.accent, lineWidth: CGFloat = 2.2) -> GlyphIcon {
        GlyphIcon(path: Icons.check, width: width, height: width * 12 / 15,
                  viewBox: CGSize(width: 15, height: 12), color: color, lineWidth: lineWidth)
    }

    static func back(color: Color = .white) -> GlyphIcon {
        GlyphIcon(path: Icons.backChevron, width: 8, height: 14,
                  viewBox: CGSize(width: 8, height: 14), color: color, lineWidth: 2)
    }
}
