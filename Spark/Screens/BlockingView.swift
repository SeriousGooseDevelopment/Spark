import SwiftUI

struct BlockingView: View {
    @Environment(Store.self) private var store

    private struct Category: Identifiable {
        var id: String { key }
        let key: String
        let label: String
        let subtitle: String
    }

    private let categories: [Category] = [
        Category(key: "ads", label: "Ads", subtitle: "Banners, video and in-app ads"),
        Category(key: "trackers", label: "Trackers", subtitle: "Analytics and cross-site tracking"),
        Category(key: "popups", label: "Pop-ups", subtitle: "Overlays and interstitials"),
        Category(key: "cookies", label: "Cookie banners", subtitle: "Consent prompts and notices"),
    ]

    private let filterLists: [Category] = [
        Category(key: "easylist", label: "Spark Essentials", subtitle: "1.2M rules · updated 2h ago"),
        Category(key: "privacy", label: "Privacy & tracking", subtitle: "480k rules · updated today"),
        Category(key: "extra", label: "Annoyances extra", subtitle: "Newsletter and app nags"),
    ]

    private struct AppRule: Identifiable {
        var id: String { key }
        let key: String
        let letter: String
        let name: String
    }

    private let appRules: [AppRule] = [
        AppRule(key: "safari", letter: "S", name: "Safari"),
        AppRule(key: "chrome", letter: "C", name: "Chrome"),
        AppRule(key: "youtube", letter: "Y", name: "YouTube"),
        AppRule(key: "reddit", letter: "R", name: "Reddit"),
    ]

    private var blockedTodayLabel: String {
        store.blockingStats.blockedToday.formatted()
    }

    var body: some View {
        HeaderScreen(title: "Blocking Controls", subtitle: "\(blockedTodayLabel) blocked today") {
            masterCard

            SectionLabel("What Spark blocks")
            GroupCard {
                SeparatedRows(items: categories) { category in
                    toggleRow(title: category.label, subtitle: category.subtitle, key: category.key)
                }
            }

            SectionLabel("Per-app rules")
            Text("Local only — doesn't affect network-wide blocking from your Spark box.")
                .font(SKFont.regular(11.5))
                .foregroundStyle(SK.ink5)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            GroupCard {
                SeparatedRows(items: appRules) { rule in
                    appRow(rule)
                }
            }

            SectionLabel("Filter lists") {
                Text("Browse all")
                    .font(SKFont.semibold(12))
                    .foregroundStyle(SK.accent)
                    .contentShape(Rectangle())
                    .onTapGesture { store.show(MenuView.filterListsDetail) }
                    .accessibilityAddTraits(.isButton)
            }
            GroupCard {
                SeparatedRows(items: filterLists) { list in
                    toggleRow(title: list.label, subtitle: list.subtitle, key: list.key)
                }
            }

            SectionLabel("Blocked sites")
            GroupCard {
                ForEach(store.blockedSites) { site in
                    siteRow(site, remove: { store.removeBlocked(site.domain) })
                    RowSeparator()
                }
                addSiteRow(title: "Block a site") { store.openForm(Forms.blockSite) }
            }

            SectionLabel("Allowed sites")
            GroupCard {
                ForEach(store.allowedSites) { site in
                    siteRow(site, remove: { store.removeAllowed(site.domain) })
                    RowSeparator()
                }
                addSiteRow(title: "Allow a site") { store.openForm(Forms.allowSite) }
            }

            SectionLabel("Blocked today by site")
            blockedBySiteCard
        }
    }

    // MARK: - Master

    private var masterCard: some View {
        let on = store.masterOn
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(on ? "Blocking is on" : "Blocking is paused")
                        .font(SKFont.bold(16))
                        .tracking(-0.3)
                        .foregroundStyle(SK.ink)
                    Text(on ? "Every app and browser on this device"
                            : "Ads and trackers are getting through")
                        .font(SKFont.regular(12.5))
                        .foregroundStyle(SK.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                SparkToggle(isOn: on) { Task { await store.toggleMaster() } }
            }

            HStack(spacing: 10) {
                statChip(store.blockingStats.blockedToday.formatted(), "Blocked")
                statChip(store.blockingStats.queriesToday.formatted(), "Queries")
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { Task { await store.toggleMaster() } }
    }

    private func statChip(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(SKFont.bold(17))
                .tracking(-0.4)
                .foregroundStyle(SK.ink)
            Text(label)
                .font(SKFont.regular(11))
                .foregroundStyle(SK.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(SK.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Rows

    private func toggleRow(title: String, subtitle: String, key: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SKFont.semibold(14.5))
                    .tracking(-0.2)
                    .foregroundStyle(SK.ink)
                Text(subtitle)
                    .font(SKFont.regular(12))
                    .foregroundStyle(SK.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            SparkToggle(isOn: store.isOn(key)) { store.toggle(key) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { store.toggle(key) }
    }

    private func appRow(_ rule: AppRule) -> some View {
        let on = store.apps[rule.key] ?? false
        return HStack(spacing: 13) {
            IconTile {
                Text(rule.letter)
                    .font(SKFont.bold(14))
                    .foregroundStyle(SK.accent)
            }
            Text(rule.name)
                .font(SKFont.semibold(14.5))
                .tracking(-0.2)
                .foregroundStyle(SK.ink)
            Spacer(minLength: 8)
            Text(on ? "Blocking" : "Paused")
                .font(SKFont.semibold(11.5))
                .foregroundStyle(on ? SK.accent : SK.ink4)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(on ? SK.chipBlue : SK.separator, in: Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleApp(rule.key) }
    }

    private func siteRow(_ site: SiteEntry, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(site.domain)
                    .font(SKFont.semibold(14.5))
                    .tracking(-0.2)
                    .foregroundStyle(SK.ink)
                Text(site.subtitle)
                    .font(SKFont.regular(12))
                    .foregroundStyle(SK.ink3)
            }
            Spacer(minLength: 8)
            Circle()
                .fill(SK.chip)
                .frame(width: 28, height: 28)
                .overlay(GlyphIcon.close())
                .contentShape(Circle())
                .onTapGesture(perform: remove)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Remove \(site.domain)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func addSiteRow(title: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            GlyphIcon.plus()
            Text(title)
                .font(SKFont.semibold(14))
                .tracking(-0.2)
                .foregroundStyle(SK.accent)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityAddTraits(.isButton)
    }

    private var blockedBySiteCard: some View {
        VStack(spacing: 0) {
            ForEach(SparkContent.blockedBySite) { entry in
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(entry.site)
                            .font(SKFont.semibold(13.5))
                            .tracking(-0.2)
                            .foregroundStyle(SK.ink)
                        Spacer(minLength: 0)
                        Text(entry.count)
                            .font(SKFont.semibold(12.5))
                            .foregroundStyle(SK.ink2)
                    }
                    SparkBar(fraction: entry.fraction)
                        .padding(.top, 7)
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
    }
}
