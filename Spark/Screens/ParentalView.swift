import SwiftUI

struct ParentalView: View {
    @Environment(Store.self) private var store

    var body: some View {
        HeaderScreen(title: "Parental Controls", subtitle: "Set per device", topPadding: 24) {
            SectionLabel("Devices", leading: 4, size: 12, color: SK.ink3, top: 0, bottom: 10)

            VStack(spacing: 10) {
                ForEach(store.devices) { device in
                    deviceCard(device)
                }

                if store.devices.isEmpty {
                    emptyState
                }

                addDeviceRow
            }
        }
    }

    private func deviceCard(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 13) {
                HStack(spacing: 9) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.name)
                            .font(SKFont.semibold(15))
                            .tracking(-0.3)
                            .foregroundStyle(SK.ink)
                        Text(device.subtitle)
                            .font(SKFont.regular(12))
                            .foregroundStyle(SK.ink4)
                    }
                    Spacer(minLength: 0)
                    Chevron(size: 12)
                }

                SparkToggle(isOn: store.isOn(device.id), compact: true) { store.toggle(device.id) }
            }

            HStack(alignment: .top, spacing: 22) {
                stat(store.value(device.id + "Limit"), "Daily limit")
                stat(store.value(device.id + "Filter"), "Filter")
                stat(store.value(device.id + "Bed"), "Bedtime")
            }
            .padding(.top, 15)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .softShadow()
        // The one card that can't toggle on a body tap: it already drills into
        // the device. The switch keeps its own tap, everything else navigates.
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { store.openDevice(device.id) }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(SKFont.semibold(13))
                .tracking(-0.2)
                .foregroundStyle(SK.ink)
            Text(label)
                .font(SKFont.regular(10.5))
                .foregroundStyle(SK.ink5)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Text("No devices yet")
                .font(SKFont.semibold(14))
                .tracking(-0.25)
                .foregroundStyle(SK.ink)
            Text("Add a device to set limits and filters.")
                .font(SKFont.regular(12.5))
                .foregroundStyle(SK.ink4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 26)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .softShadow()
    }

    private var addDeviceRow: some View {
        HStack(spacing: 9) {
            GlyphIcon.plus(size: 16)
            Text("Add a device")
                .font(SKFont.semibold(14))
                .tracking(-0.2)
                .foregroundStyle(SK.accent)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .softShadow()
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { Task { await store.startDeviceClaim() } }
        .accessibilityAddTraits(.isButton)
    }
}
