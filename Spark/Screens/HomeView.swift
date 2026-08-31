import SwiftUI

struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(\.safeTop) private var safeTop

    var body: some View {
        ZStack(alignment: .top) {
            SK.homeGradient

            VStack(alignment: .leading, spacing: 0) {
                Text("Spark")
                    .font(SKFont.bold(17))
                    .tracking(-0.4)
                    .foregroundStyle(.white)
                    .frame(height: 30, alignment: .center)

                // Sits in the normal layout flow (unlike the bottom-anchored
                // "Spark Connected" pill) specifically so it can never overlap
                // the dial below regardless of screen height.
                if !store.sparkConnected {
                    connectPrompt
                        .padding(.top, 10)
                }

                // The blocked count leads the screen; the dial now carries only
                // the master control.
                Text(store.blockingStats.blockedToday.formatted())
                    .font(SKFont.semibold(44))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .padding(.top, 44)

                Text("Ads blocked today")
                    .font(SKFont.medium(16))
                    .tracking(-0.2)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.top, 2)

                subtitle
                    .padding(.top, 14)

                dial
                    .frame(maxWidth: .infinity)
                    .padding(.top, 78)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 26)
            .padding(.top, safeTop + 6)
        }
    }

    /// The caption ends in a circular chevron sitting inline after the last
    /// word. SwiftUI has no inline text attachment that stays independently
    /// tappable, so the closing line is split out to hold that placement —
    /// laying the whole caption out in one `Text` would strand the chevron at
    /// the paragraph's right edge instead.
    private var subtitle: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Protection is on for every app")
            HStack(spacing: 7) {
                Text("and browser")
                Circle()
                    .fill(.white.opacity(0.34))
                    .frame(width: 17, height: 17)
                    .overlay {
                        GlyphIcon(path: "M2.6 1.2L5.4 4l-2.8 2.8", width: 8, height: 8,
                                  viewBox: CGSize(width: 8, height: 8), color: .white, lineWidth: 1.5)
                    }
                    .contentShape(Circle())
                    .onTapGesture { store.go(.blocking) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Blocking controls")
            }
        }
        .font(SKFont.regular(13.5))
        .tracking(-0.05)
        .foregroundStyle(.white.opacity(0.86))
    }

    private var dial: some View {
        ArcDial(side: 222) {
            masterButton
                .padding(.top, 16)
        }
    }

    /// A frosted disc filling the dial, with its label beneath. Tapping either
    /// half toggles blocking.
    private var masterButton: some View {
        let on = store.masterOn
        return VStack(spacing: 20) {
            Circle()
                .fill(.white.opacity(on ? 0.26 : 0.42))
                .frame(width: 86, height: 86)
                .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                .overlay { glyph(on: on) }
                .shadow(color: .white.opacity(0.15), radius: 14)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(on ? "Stop blocking ads" : "Start blocking ads")

            Text(on ? "Stop Blocking Ads" : "Start Blocking Ads")
                .font(SKFont.semibold(14.5))
                .tracking(-0.2)
                .foregroundStyle(.white)
        }
        .contentShape(Rectangle())
        .onTapGesture { Task { await store.toggleMaster() } }
    }

    private var connectPrompt: some View {
        HStack(spacing: 8) {
            Text("Connect your Spark box")
                .font(SKFont.semibold(12.5))
                .tracking(-0.1)
            Chevron(size: 10, color: .white, lineWidth: 1.6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.18), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { store.push(.pairing) }
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func glyph(on: Bool) -> some View {
        if on {
            HStack(spacing: 7) {
                Capsule().fill(.white).frame(width: 7, height: 26)
                Capsule().fill(.white).frame(width: 7, height: 26)
            }
        } else {
            SVGPathShape(commands: "M1.4 1.3a.6.6 0 0 1 .92-.5l7 4.7a.6.6 0 0 1 0 1l-7 4.7a.6.6 0 0 1-.92-.5z",
                         viewBox: CGSize(width: 11, height: 12))
                .fill(.white)
                .frame(width: 26, height: 28)
                // A triangle reads as centred only when nudged toward its point.
                .offset(x: 2)
        }
    }
}
