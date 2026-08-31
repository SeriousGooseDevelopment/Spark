import SwiftUI

/// A `Shape` that draws an SVG path `d` string, scaled from its viewBox into the
/// shape's rect. The design carries its icons as inline SVG, so parsing them
/// once keeps every glyph identical to the source instead of hand-traced.
///
/// Supports the subset the design uses: M/m, L/l, H/h, V/v, C/c, S/s, Q/q, A/a, Z/z.
struct SVGPathShape: Shape {
    var commands: String
    /// The viewBox the commands are authored in.
    var viewBox: CGSize = CGSize(width: 24, height: 24)

    init(commands: String, viewBox: CGSize = CGSize(width: 24, height: 24)) {
        self.commands = commands
        self.viewBox = viewBox
    }

    init(commands: String, viewBox side: CGFloat) {
        self.init(commands: commands, viewBox: CGSize(width: side, height: side))
    }

    func path(in rect: CGRect) -> Path {
        // Uniform fit, centred — SVG's default `preserveAspectRatio="xMidYMid meet"`.
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let dx = rect.minX + (rect.width - viewBox.width * scale) / 2
        let dy = rect.minY + (rect.height - viewBox.height * scale) / 2
        let transform = CGAffineTransform(translationX: dx, y: dy)
            .scaledBy(x: scale, y: scale)
        return SVGPathParser(commands).parse().applying(transform)
    }
}

// MARK: - Parser

struct SVGPathParser {
    private let source: String

    init(_ source: String) { self.source = source }

    func parse() -> Path {
        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?

        var scanner = TokenScanner(source)

        while let command = scanner.nextCommand() {
            let relative = command.isLowercase
            let op = Character(command.uppercased())
            var isFirstPair = true

            // A repeated coordinate set with no new letter reuses the command —
            // except that a repeated moveto degrades into a lineto.
            repeat {
                switch op {
                case "M":
                    guard let p = scanner.point(relative: relative, origin: current) else { break }
                    if isFirstPair {
                        path.move(to: p)
                        subpathStart = p
                    } else {
                        path.addLine(to: p)
                    }
                    current = p
                    lastControl = nil

                case "L":
                    guard let p = scanner.point(relative: relative, origin: current) else { break }
                    path.addLine(to: p)
                    current = p
                    lastControl = nil

                case "H":
                    guard let x = scanner.number() else { break }
                    let p = CGPoint(x: relative ? current.x + x : x, y: current.y)
                    path.addLine(to: p)
                    current = p
                    lastControl = nil

                case "V":
                    guard let y = scanner.number() else { break }
                    let p = CGPoint(x: current.x, y: relative ? current.y + y : y)
                    path.addLine(to: p)
                    current = p
                    lastControl = nil

                case "C":
                    guard let c1 = scanner.point(relative: relative, origin: current),
                          let c2 = scanner.point(relative: relative, origin: current),
                          let end = scanner.point(relative: relative, origin: current) else { break }
                    path.addCurve(to: end, control1: c1, control2: c2)
                    current = end
                    lastControl = c2

                case "S":
                    guard let c2 = scanner.point(relative: relative, origin: current),
                          let end = scanner.point(relative: relative, origin: current) else { break }
                    let c1 = reflect(lastControl, around: current)
                    path.addCurve(to: end, control1: c1, control2: c2)
                    current = end
                    lastControl = c2

                case "Q":
                    guard let c = scanner.point(relative: relative, origin: current),
                          let end = scanner.point(relative: relative, origin: current) else { break }
                    path.addQuadCurve(to: end, control: c)
                    current = end
                    lastControl = c

                case "A":
                    guard let rx = scanner.number(), let ry = scanner.number(),
                          let rotation = scanner.number(),
                          let largeArc = scanner.flag(), let sweep = scanner.flag(),
                          let end = scanner.point(relative: relative, origin: current) else { break }
                    appendArc(&path, from: current, to: end,
                              rx: rx, ry: ry, rotationDegrees: rotation,
                              largeArc: largeArc, sweep: sweep)
                    current = end
                    lastControl = nil

                case "Z":
                    path.closeSubpath()
                    current = subpathStart
                    lastControl = nil

                default:
                    break
                }
                isFirstPair = false
            } while op != "Z" && scanner.hasImplicitRepeat()
        }

        return path
    }

    private func reflect(_ control: CGPoint?, around point: CGPoint) -> CGPoint {
        guard let control else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    /// Endpoint-to-center conversion, per the SVG implementation notes (F.6.5).
    private func appendArc(_ path: inout Path, from start: CGPoint, to end: CGPoint,
                           rx rxIn: CGFloat, ry ryIn: CGFloat, rotationDegrees: CGFloat,
                           largeArc: Bool, sweep: Bool) {
        var rx = abs(rxIn), ry = abs(ryIn)
        guard rx > 0, ry > 0, start != end else {
            path.addLine(to: end)
            return
        }

        let phi = rotationDegrees * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)

        let dx2 = (start.x - end.x) / 2
        let dy2 = (start.y - end.y) / 2
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2

        // Scale the radii up if they are too small to span the endpoints.
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let s = sqrt(lambda)
            rx *= s
            ry *= s
        }

        let sign: CGFloat = (largeArc != sweep) ? 1 : -1
        let numerator = max(0, rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p)
        let denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let coefficient = denominator == 0 ? 0 : sign * sqrt(numerator / denominator)

        let cxp = coefficient * rx * y1p / ry
        let cyp = -coefficient * ry * x1p / rx

        let cx = cosPhi * cxp - sinPhi * cyp + (start.x + end.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (start.y + end.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            guard len > 0 else { return 0 }
            let a = acos(min(1, max(-1, dot / len)))
            return (ux * vy - uy * vx < 0) ? -a : a
        }

        let startAngle = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var sweepAngle = angle((x1p - cxp) / rx, (y1p - cyp) / ry,
                               (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep, sweepAngle > 0 { sweepAngle -= 2 * .pi }
        if sweep, sweepAngle < 0 { sweepAngle += 2 * .pi }

        // Approximate with cubics, at most a quarter turn each.
        let segments = max(1, Int(ceil(abs(sweepAngle) / (.pi / 2))))
        let delta = sweepAngle / CGFloat(segments)
        let alpha = 4.0 / 3.0 * tan(delta / 4)

        var theta = startAngle
        var from = start
        for _ in 0..<segments {
            let theta2 = theta + delta
            let cosT1 = cos(theta), sinT1 = sin(theta)
            let cosT2 = cos(theta2), sinT2 = sin(theta2)

            let e2 = CGPoint(
                x: cx + rx * cosPhi * cosT2 - ry * sinPhi * sinT2,
                y: cy + rx * sinPhi * cosT2 + ry * cosPhi * sinT2
            )
            let d1 = CGPoint(
                x: -rx * cosPhi * sinT1 - ry * sinPhi * cosT1,
                y: -rx * sinPhi * sinT1 + ry * cosPhi * cosT1
            )
            let d2 = CGPoint(
                x: -rx * cosPhi * sinT2 - ry * sinPhi * cosT2,
                y: -rx * sinPhi * sinT2 + ry * cosPhi * cosT2
            )

            path.addCurve(
                to: e2,
                control1: CGPoint(x: from.x + alpha * d1.x, y: from.y + alpha * d1.y),
                control2: CGPoint(x: e2.x - alpha * d2.x, y: e2.y - alpha * d2.y)
            )

            theta = theta2
            from = e2
        }
    }
}

// MARK: - Tokenizer

private struct TokenScanner {
    private let chars: [Character]
    private var index: Int = 0

    init(_ source: String) { chars = Array(source) }

    private mutating func skipSeparators() {
        while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index] == "\n" || chars[index] == "\t" || chars[index] == "\r" {
            index += 1
        }
    }

    mutating func nextCommand() -> Character? {
        skipSeparators()
        guard index < chars.count else { return nil }
        let c = chars[index]
        guard c.isLetter else { return nil }
        index += 1
        return c
    }

    /// A following number with no command letter means "repeat the last command".
    mutating func hasImplicitRepeat() -> Bool {
        skipSeparators()
        guard index < chars.count else { return false }
        let c = chars[index]
        return c.isNumber || c == "-" || c == "+" || c == "."
    }

    mutating func number() -> CGFloat? {
        skipSeparators()
        var buffer = ""
        var seenDigit = false
        while index < chars.count {
            let c = chars[index]
            if c == "-" || c == "+" {
                // A sign only starts a number, or follows an exponent marker.
                if buffer.isEmpty || buffer.last == "e" || buffer.last == "E" {
                    buffer.append(c); index += 1; continue
                }
                break
            }
            if c == "." {
                // A second dot starts the next number (e.g. "1.5.5").
                if buffer.contains(".") { break }
                buffer.append(c); index += 1; continue
            }
            if c.isNumber {
                seenDigit = true
                buffer.append(c); index += 1; continue
            }
            if (c == "e" || c == "E") && seenDigit {
                buffer.append(c); index += 1; continue
            }
            break
        }
        guard seenDigit, let value = Double(buffer) else { return nil }
        return CGFloat(value)
    }

    /// Arc flags are single characters and may be packed without separators.
    mutating func flag() -> Bool? {
        skipSeparators()
        guard index < chars.count else { return nil }
        let c = chars[index]
        guard c == "0" || c == "1" else { return number().map { $0 != 0 } }
        index += 1
        return c == "1"
    }

    mutating func point(relative: Bool, origin: CGPoint) -> CGPoint? {
        guard let x = number(), let y = number() else { return nil }
        return relative ? CGPoint(x: origin.x + x, y: origin.y + y) : CGPoint(x: x, y: y)
    }
}
