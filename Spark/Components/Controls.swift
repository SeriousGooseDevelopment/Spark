import SwiftUI

// MARK: - Toggle

/// The pill switch used everywhere. Two sizes: 46×28 on the main lists,
/// 44×27 on device cards and detail rows.
struct SparkToggle: View {
    var isOn: Bool
    var compact: Bool = false
    var action: () -> Void

    private var width: CGFloat { compact ? 44 : 46 }
    private var height: CGFloat { compact ? 27 : 28 }
    private var knob: CGFloat { compact ? 23 : 24 }
    private var travel: CGFloat { compact ? 17 : 18 }

    var body: some View {
        Capsule()
            .fill(isOn ? SK.accent : SK.track)
            .frame(width: width, height: height)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .shadow(color: Color(hex: 0x101836, opacity: 0.22), radius: 1.5, x: 0, y: 1)
                    .padding(2)
                    .offset(x: isOn ? travel : 0)
            }
            .contentShape(Capsule())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isOn ? "On" : "Off")
    }
}

// MARK: - Chevrons

struct Chevron: View {
    var size: CGFloat = 12
    var color: Color = SK.chevron
    var lineWidth: CGFloat = 1.8

    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: size * 0.42, y: size / 2))
            p.addLine(to: CGPoint(x: 0, y: size))
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        .frame(width: size * 0.42, height: size)
    }
}

// MARK: - Cards and sections

/// Section label above a card group.
struct SectionLabel: View {
    var text: String
    var leading: CGFloat = 6
    var size: CGFloat = 12.5
    var color: Color = SK.ink2
    var top: CGFloat = 22
    var bottom: CGFloat = 8
    var trailing: AnyView?

    init(_ text: String, leading: CGFloat = 6, size: CGFloat = 12.5,
         color: Color = SK.ink2, top: CGFloat = 22, bottom: CGFloat = 8) {
        self.text = text
        self.leading = leading
        self.size = size
        self.color = color
        self.top = top
        self.bottom = bottom
        self.trailing = nil
    }

    init<T: View>(_ text: String, leading: CGFloat = 6, size: CGFloat = 12.5,
                  color: Color = SK.ink2, top: CGFloat = 22, bottom: CGFloat = 8,
                  @ViewBuilder trailing: () -> T) {
        self.text = text
        self.leading = leading
        self.size = size
        self.color = color
        self.top = top
        self.bottom = bottom
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(SKFont.semibold(size))
                .foregroundStyle(color)
            if let trailing {
                Spacer(minLength: 12)
                trailing
            }
        }
        .padding(.leading, leading)
        .padding(.top, top)
        .padding(.bottom, bottom)
    }
}

/// A rounded white group that clips its rows.
struct GroupCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var soft: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .background(SK.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .modifier(CardShadow(soft: soft))
    }
}

private struct CardShadow: ViewModifier {
    var soft: Bool
    func body(content: Content) -> some View {
        if soft { content.softShadow() } else { content.cardShadow() }
    }
}

/// Hairline between rows inside a `GroupCard`. Suppressed after the last row so
/// the group's bottom edge stays clean.
struct RowSeparator: View {
    var color: Color = SK.separator
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

/// Lays rows out with separators between — but not after — them.
struct SeparatedRows<Item: Identifiable, Row: View>: View {
    var items: [Item]
    var separator: Color = SK.separator
    @ViewBuilder var row: (Item) -> Row

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            row(item)
            if index < items.count - 1 {
                RowSeparator(color: separator)
            }
        }
    }
}

// MARK: - Progress bar

struct SparkBar: View {
    var fraction: Double
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(SK.barTrack)
                Capsule()
                    .fill(SK.accent)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Icon

/// Renders one of the design's inline SVG icons. `lineWidth` is given in the
/// path's own viewBox units and scales with the rendered size.
struct StrokeIcon: View {
    var path: String
    var size: CGFloat = 19
    var viewBox: CGFloat = 24
    var color: Color = SK.accent
    var lineWidth: CGFloat = 1.9

    var body: some View {
        SVGPathShape(commands: path, viewBox: viewBox)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth * size / viewBox,
                                              lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

/// The blue rounded-square icon tile in front of menu and sheet rows.
struct IconTile<Content: View>: View {
    var side: CGFloat = 34
    var corner: CGFloat = 11
    var background: Color = SK.chipBlue
    var shadowed: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(background)
            .frame(width: side, height: side)
            .overlay(content())
            .modifier(TileShadow(on: shadowed))
    }
}

private struct TileShadow: ViewModifier {
    var on: Bool
    func body(content: Content) -> some View {
        if on {
            content.shadow(color: Color(hex: 0x1C2C5A, opacity: 0.08), radius: 1.5, x: 0, y: 1)
        } else {
            content
        }
    }
}
