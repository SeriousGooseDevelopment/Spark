import SwiftUI

/// The 96pt bar: four labelled tabs with a floating action button punched
/// through the middle. Sits above every screen, including the pushed ones.
struct SparkTabBar: View {
    var current: Tab
    var sheetOpen: Bool
    var onSelect: (Tab) -> Void
    var onFAB: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            item(.home, icon: Icons.tabHome, lineWidth: 2.1, label: "Home")
            item(.blocking, icon: Icons.tabBlocking, lineWidth: 2, label: "Blocking\nControls")
            fab
            item(.parental, icon: Icons.tabParental, lineWidth: 2, label: "Parental\nControls")
            item(.menu, icon: Icons.tabMenu, lineWidth: 2, label: "Menu")
        }
        .padding(.horizontal, 14)
        .padding(.top, 15)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: SK.tabBarHeight, alignment: .top)
        .background(SK.card)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .continuous))
    }

    private func item(_ tab: Tab, icon: String, lineWidth: CGFloat, label: String) -> some View {
        let active = current == tab
        return VStack(spacing: 6) {
            StrokeIcon(
                path: icon,
                size: 26,
                viewBox: 26,
                color: active ? SK.inkStrong : SK.tabInactiveIcon,
                lineWidth: lineWidth
            )
            Text(label)
                .font(SKFont.face(9.5, active ? 700 : 600))
                .tracking(-0.05)
                .lineSpacing(1.5)
                .multilineTextAlignment(.center)
                .foregroundStyle(active ? SK.inkStrong : SK.tabInactiveLabel)
        }
        .frame(width: 72)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(tab) }
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(label.replacingOccurrences(of: "\n", with: " "))
    }

    private var fab: some View {
        Circle()
            .fill(SK.accent)
            .frame(width: 54, height: 54)
            .overlay {
                GlyphIcon(path: "M11 4.4v13.2 M4.4 11h13.2", width: 22, height: 22,
                          viewBox: CGSize(width: 22, height: 22), color: .white, lineWidth: 2.2)
                    .rotationEffect(.degrees(sheetOpen ? 45 : 0))
            }
            .shadow(color: SK.accent.opacity(0.34), radius: 9, x: 0, y: 8)
            // The design draws the ring as an outward 5px spread, so it sits
            // outside the blue rather than eating into it.
            .padding(5)
            .background(Circle().fill(SK.card))
            .padding(.top, -5)
            .contentShape(Circle())
            .onTapGesture(perform: onFAB)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Quick actions")
            .frame(maxWidth: .infinity)
    }
}

/// The pale strip that peeks out either side beneath the bar, giving the tab
/// bar its stacked-card look.
struct TabBarShelf: View {
    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
            .fill(SK.shelf)
            .frame(height: 107)
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

/// The "Spark Connected" chip that floats above the bar on Home. Only shown
/// once actually paired — tappable to see the paired box's details. The
/// "not connected yet" case is a separate, inline prompt in HomeView itself
/// (see `HomeView.connectPrompt`), not this absolutely-positioned pill: two
/// bottom-anchored elements sharing the same slot risked overlapping the
/// dial's hit-testing region depending on screen height.
struct ConnectedPill: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Spark Connected")
                .font(SKFont.semibold(13.5))
                .tracking(-0.2)
                .foregroundStyle(Color(hex: 0x101114))
            BatteryGlyph()
        }
        .padding(.horizontal, 21)
        .frame(height: 40)
        .background(SK.card, in: Capsule())
        .shadow(color: Color(hex: 0x263A78, opacity: 0.13), radius: 12, x: 0, y: 10)
    }
}

private struct BatteryGlyph: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color(hex: 0xD7DAE0), lineWidth: 1.5)
                .frame(width: 16.5, height: 10.5)
            RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                .fill(SK.green)
                .frame(width: 12.8, height: 6.8)
                .offset(x: 1.85)
            Capsule()
                .fill(Color(hex: 0xD7DAE0))
                .frame(width: 1.6, height: 3.6)
                .offset(x: 18.2)
        }
        .frame(width: 21, height: 12, alignment: .leading)
    }
}
