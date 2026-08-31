import SwiftUI

/// Live Bonjour discovery — deliberately a bespoke view rather than a
/// `DetailSpec`. `DetailSpec.rows` is a snapshot taken once when the screen
/// opens; discovered boxes arrive over 1-5 seconds as mDNS responses come in,
/// which the `DetailRow` vocabulary has no way to express without breaking
/// its "pure data" contract for every other screen that uses it.
struct PairingView: View {
    @Environment(Store.self) private var store

    var body: some View {
        PushedScreen(title: "Connect your Spark box", subtitle: "Looking on your Wi-Fi network", onBack: store.back) {
            if store.discoveredBoxes.isEmpty {
                scanningCard
            } else {
                SectionLabel("Boxes found", leading: 4, size: 12, color: SK.ink3, top: 0, bottom: 10)
                GroupCard(cornerRadius: 18, soft: true) {
                    SeparatedRows(items: store.discoveredBoxes, separator: SK.separatorSoft) { box in
                        boxRow(box)
                    }
                }
            }
        }
        .onAppear { store.startPairingDiscovery() }
        .onDisappear { store.stopPairingDiscovery() }
    }

    private var scanningCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Looking for your Spark box…")
                .font(SKFont.semibold(14))
                .tracking(-0.2)
                .foregroundStyle(SK.ink)
            Text("Make sure it's powered on and connected to the same Wi-Fi network as this phone.")
                .font(SKFont.regular(12.5))
                .foregroundStyle(SK.ink4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .softShadow()
    }

    private func boxRow(_ box: DiscoveredBox) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(box.name)
                    .font(SKFont.semibold(14.5))
                    .tracking(-0.2)
                    .foregroundStyle(SK.ink)
                Text(box.host)
                    .font(SKFont.regular(12))
                    .foregroundStyle(SK.ink3)
            }
            Spacer(minLength: 8)
            if store.networkState == .loading {
                ProgressView().controlSize(.small)
            } else {
                Chevron(size: 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { Task { await store.pair(to: box) } }
        .allowsHitTesting(store.networkState != .loading)
    }
}
