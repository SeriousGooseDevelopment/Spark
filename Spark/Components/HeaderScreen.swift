import SwiftUI

/// Blocking / Parental / Menu share one shape: an indigo band across the top
/// with a title, and a rounded canvas panel that slides up over it and scrolls.
struct HeaderScreen<Content: View>: View {
    var title: String
    var subtitle: String
    var horizontalPadding: CGFloat = 20
    var topPadding: CGFloat = 20
    @ViewBuilder var content: () -> Content

    @Environment(\.safeTop) private var safeTop

    /// Design offsets are absolute from the top of the display, where the
    /// status bar is 62pt. Re-anchoring to the safe area keeps them right on
    /// every device.
    private var bandHeight: CGFloat { safeTop + 128 }
    private var titleTop: CGFloat { safeTop + 4 }
    private var panelTop: CGFloat { safeTop + 90 }

    var body: some View {
        ZStack(alignment: .top) {
            SK.canvas

            SK.headerGradient
                .frame(height: bandHeight)
                .frame(maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(SKFont.semibold(26))
                    .tracking(-0.7)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(SKFont.regular(13))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, titleTop)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0, content: content)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)
                    .padding(.bottom, SK.tabBarHeight + 30)
            }
            .background(SK.canvas)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: SK.panelCornerRadius,
                topTrailingRadius: SK.panelCornerRadius,
                style: .continuous
            ))
            .padding(.top, panelTop)
        }
    }
}

/// Device detail and the generic detail screen share a second shape: a shorter
/// band with a back button, and a panel that runs to the bottom of the screen.
struct PushedScreen<Content: View>: View {
    var title: String
    var subtitle: String
    var onBack: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.safeTop) private var safeTop

    private var bandHeight: CGFloat { safeTop + 116 }
    private var backTop: CGFloat { safeTop }
    private var titleTop: CGFloat { safeTop + 42 }
    private var panelTop: CGFloat { safeTop + 104 }

    var body: some View {
        ZStack(alignment: .top) {
            SK.canvas

            SK.headerGradient
                .frame(height: bandHeight)
                .frame(maxHeight: .infinity, alignment: .top)

            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 34, height: 34)
                .overlay(GlyphIcon.back())
                .contentShape(Circle())
                .onTapGesture(perform: onBack)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Back")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.top, backTop)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(SKFont.semibold(24))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(SKFont.regular(12.5))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, titleTop)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0, content: content)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 34)
            }
            .background(SK.canvas)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: SK.panelCornerRadius,
                topTrailingRadius: SK.panelCornerRadius,
                style: .continuous
            ))
            .padding(.top, panelTop)
        }
    }
}
