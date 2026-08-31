import SwiftUI

struct DeviceDetailView: View {
    @Environment(Store.self) private var store
    var deviceID: String

    private var device: Device {
        store.devices.first { $0.id == deviceID }
            ?? Device(id: deviceID, name: "", subtitle: "", usedMinutes: 0)
    }

    private struct Rule: Identifiable {
        let id = UUID()
        var label: String
        var value: String
        var valueKey: String
        var options: [String]
    }

    private var rules: [Rule] {
        [
            Rule(label: "Daily screen time", value: store.value(device.id + "Limit"),
                 valueKey: device.id + "Limit", options: RuleOptions.limit),
            Rule(label: "Bedtime", value: store.value(device.id + "Bed"),
                 valueKey: device.id + "Bed", options: RuleOptions.bedtime),
            Rule(label: "Content filter", value: store.value(device.id + "Filter"),
                 valueKey: device.id + "Filter", options: RuleOptions.filter),
        ]
    }

    var body: some View {
        PushedScreen(title: device.name, subtitle: device.subtitle, onBack: store.back) {
            enabledCard

            SectionLabel("Device", leading: 4, size: 12, color: SK.ink3, bottom: 10)
            GroupCard(cornerRadius: 18, soft: true) {
                HStack(spacing: 12) {
                    Text("Name")
                        .font(SKFont.medium(14.5))
                        .tracking(-0.2)
                        .foregroundStyle(SK.ink)
                    Spacer(minLength: 8)
                    Text(device.name)
                        .font(SKFont.regular(13))
                        .foregroundStyle(SK.ink4)
                    Chevron(size: 12)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
                .onTapGesture { store.openForm(Forms.renameDevice(device.id)) }
                .accessibilityAddTraits(.isButton)
            }

            SectionLabel("Limits", leading: 4, size: 12, color: SK.ink3, bottom: 10)
            GroupCard(cornerRadius: 18, soft: true) {
                SeparatedRows(items: rules, separator: SK.separatorSoft) { rule in
                    ruleRow(rule)
                }
            }

            SectionLabel("Today", leading: 4, size: 12, color: SK.ink3, bottom: 10)
            usageCard

            SectionLabel("Blocked apps", leading: 4, size: 12, color: SK.ink3, bottom: 10)
            blockedAppsCard

            SectionLabel("Blocked sites", leading: 4, size: 12, color: SK.ink3, bottom: 10)
            blockedSitesCard

            removeButton
                .padding(.top, 18)
        }
        .task(id: device.id) {
            // Real (MAC-keyed) devices only — `refreshDeviceUsage` no-ops for
            // the seed devices. Matches the Agent's own 30s enforcement tick.
            await store.loadServiceCatalogIfNeeded()
            await store.loadDeviceBlocklist(device.id)
            await store.refreshDeviceUsage(device.id)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { break }
                await store.refreshDeviceUsage(device.id)
            }
        }
    }

    // MARK: - Blocked apps

    private var blockedAppsCard: some View {
        let blockedIDs = store.deviceBlocklists[device.id]?.apps ?? []
        return GroupCard(cornerRadius: 18, soft: true) {
            ForEach(blockedIDs, id: \.self) { appID in
                blockedAppRow(appID)
                RowSeparator(color: SK.separatorSoft)
            }
            addAppRow
        }
    }

    private func blockedAppRow(_ appID: String) -> some View {
        let name = store.serviceCatalog.first { $0.id == appID }?.name ?? appID
        return HStack(spacing: 12) {
            Text(name)
                .font(SKFont.semibold(14.5))
                .tracking(-0.2)
                .foregroundStyle(SK.ink)
            Spacer(minLength: 8)
            Circle()
                .fill(SK.chip)
                .frame(width: 26, height: 26)
                .overlay(GlyphIcon.close())
                .contentShape(Circle())
                .onTapGesture { store.toggleBlockedApp(device.id, appID) }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Remove \(name)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private var addAppRow: some View {
        HStack(spacing: 10) {
            GlyphIcon.plus()
            Text("Block an app")
                .font(SKFont.semibold(14))
                .tracking(-0.2)
                .foregroundStyle(SK.accent)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { store.openAppPicker(for: device.id) }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Blocked sites

    private var blockedSitesCard: some View {
        let sites = store.deviceBlocklists[device.id]?.sites ?? []
        return GroupCard(cornerRadius: 18, soft: true) {
            ForEach(sites, id: \.self) { domain in
                blockedSiteRow(domain)
                RowSeparator(color: SK.separatorSoft)
            }
            addSiteRow
        }
    }

    private func blockedSiteRow(_ domain: String) -> some View {
        HStack(spacing: 12) {
            Text(domain)
                .font(SKFont.semibold(14.5))
                .tracking(-0.2)
                .foregroundStyle(SK.ink)
            Spacer(minLength: 8)
            Circle()
                .fill(SK.chip)
                .frame(width: 26, height: 26)
                .overlay(GlyphIcon.close())
                .contentShape(Circle())
                .onTapGesture { store.removeBlockedSite(device.id, domain) }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Remove \(domain)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private var addSiteRow: some View {
        HStack(spacing: 10) {
            GlyphIcon.plus()
            Text("Block a site")
                .font(SKFont.semibold(14))
                .tracking(-0.2)
                .foregroundStyle(SK.accent)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { store.openForm(Forms.addBlockedSite(device.id)) }
        .accessibilityAddTraits(.isButton)
    }

    private var enabledCard: some View {
        let on = store.isOn(device.id)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Parental controls")
                    .font(SKFont.semibold(14.5))
                    .tracking(-0.25)
                    .foregroundStyle(SK.ink)
                Text(on ? "Limits and filters are enforced"
                        : "Nothing is enforced on this device")
                    .font(SKFont.regular(12))
                    .foregroundStyle(SK.ink4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            SparkToggle(isOn: on, compact: true) { store.toggle(device.id) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .softShadow()
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { store.toggle(device.id) }
    }

    private func ruleRow(_ rule: Rule) -> some View {
        HStack(spacing: 12) {
            Text(rule.label)
                .font(SKFont.medium(14.5))
                .tracking(-0.2)
                .foregroundStyle(SK.ink)
            Spacer(minLength: 8)
            Text(rule.value)
                .font(SKFont.regular(13))
                .foregroundStyle(SK.ink4)
            Chevron(size: 12)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            store.openPicker(valueKey: rule.valueKey, title: rule.label, options: rule.options)
        }
    }

    private var usageCard: some View {
        let usage = store.usage(for: device)
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(usage.label)
                    .font(SKFont.semibold(14.5))
                    .tracking(-0.25)
                    .foregroundStyle(SK.ink)
                Spacer(minLength: 8)
                Text(usage.caption)
                    .font(SKFont.regular(12))
                    .foregroundStyle(SK.ink4)
            }
            SparkBar(fraction: usage.fraction)
                .padding(.top, 11)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .softShadow()
    }

    private var removeButton: some View {
        Text("Remove device")
            .font(SKFont.semibold(14))
            .tracking(-0.2)
            .foregroundStyle(SK.danger)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(SK.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .softShadow()
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture {
                store.ask(ConfirmSpec(
                    title: "Remove \(device.name)?",
                    body: "Spark stops filtering on this device and its limits are deleted.",
                    actionLabel: "Remove device",
                    then: .removeDevice,
                    deviceID: device.id
                ))
            }
    }
}
