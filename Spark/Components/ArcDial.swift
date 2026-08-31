import SwiftUI

/// The 222pt ring on Home: three gradient arc segments with two gaps, over a
/// soft indigo bloom. Angles are transcribed from the design's SVG arc
/// endpoints (centre 111,111, radius 110, y pointing down).
struct ArcDial<Center: View>: View {
    var side: CGFloat = 222
    @ViewBuilder var center: () -> Center

    /// start / end in degrees, measured the SVG way: 0° at 3 o'clock, angles
    /// increasing clockwise on screen. Each segment sweeps counter-clockwise.
    private struct Segment {
        var start: Double
        var end: Double
        var lineWidth: CGFloat
        var gradient: LinearGradient
    }

    private var segments: [Segment] {
        [
            // Long upper-left sweep: bright at the top, fading downward.
            Segment(start: -84, end: -230, lineWidth: 2.6, gradient: LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.95), location: 0),
                    .init(color: .white.opacity(0.42), location: 0.42),
                    .init(color: .white.opacity(0.14), location: 1),
                ],
                startPoint: UnitPoint(x: 0.78, y: 0.02), endPoint: UnitPoint(x: 0.14, y: 0.92)
            )),
            // Bottom sweep: dim on the left, brightening to the right.
            Segment(start: 130, end: 45, lineWidth: 2.6, gradient: LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.16), location: 0),
                    .init(color: .white.opacity(0.50), location: 0.55),
                    .init(color: .white.opacity(0.96), location: 1),
                ],
                startPoint: UnitPoint(x: 0.08, y: 0.90), endPoint: UnitPoint(x: 0.96, y: 0.86)
            )),
            // The unfilled remainder on the right.
            Segment(start: 28, end: -68, lineWidth: 2.4, gradient: LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.40), location: 0),
                    .init(color: .white.opacity(0.14), location: 1),
                ],
                startPoint: UnitPoint(x: 0.90, y: 0.85), endPoint: UnitPoint(x: 0.60, y: 0.05)
            )),
        ]
    }

    var body: some View {
        ZStack {
            bloom
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                segment.gradient
                    .mask(
                        ArcSegment(start: segment.start, end: segment.end)
                            .stroke(style: StrokeStyle(lineWidth: segment.lineWidth * side / 222,
                                                       lineCap: .round))
                    )
            }
            center()
        }
        .frame(width: side, height: side)
    }

    /// The blurred radial glow sitting just behind and below the ring.
    private var bloom: some View {
        let scale = side / 222
        return Ellipse()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: Color(hex: 0x3A42BE, opacity: 0.95), location: 0.00),
                        .init(color: Color(hex: 0x424CC6, opacity: 0.90), location: 0.30),
                        .init(color: Color(hex: 0x5464CE, opacity: 0.80), location: 0.50),
                        .init(color: Color(hex: 0x7086D8, opacity: 0.62), location: 0.66),
                        .init(color: Color(hex: 0x92AAE2, opacity: 0.40), location: 0.80),
                        .init(color: Color(hex: 0xB6CAE9, opacity: 0.18), location: 0.91),
                        .init(color: .white.opacity(0), location: 1.00),
                    ],
                    center: UnitPoint(x: 0.45, y: 0.41),
                    startRadius: 0,
                    // 58% of the bloom's 220pt width, per the design's radial stop.
                    endRadius: 128 * scale
                )
            )
            .frame(width: 220 * scale, height: 240 * scale)
            .blur(radius: 19 * scale)
            .offset(x: -2 * scale, y: -1 * scale)
    }
}

/// One arc of the ring, swept counter-clockwise from `start` to `end`.
private struct ArcSegment: Shape {
    var start: Double
    var end: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2 * (110 / 111)
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            // SwiftUI's y axis points down, so a decreasing angle — the SVG
            // sweep-flag-0 direction — is `clockwise: true` here.
            clockwise: true
        )
        return path
    }
}
