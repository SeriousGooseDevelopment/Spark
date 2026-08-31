import SwiftUI

struct MenuView: View {
    @Environment(Store.self) private var store

    private struct MenuRow: Identifiable {
        let id = UUID()
        var label: String
        var value: String = ""
        var icon: String
        var action: () -> Void
    }

    var body: some View {
        HeaderScreen(title: "Menu", subtitle: "Account, devices and how Spark filters") {
            accountCard

            SectionLabel("Protection")
            GroupCard {
                SeparatedRows(items: protectionRows) { row in
                    menuRow(row, showsValue: true)
                }
            }

            SectionLabel("Support")
            GroupCard {
                SeparatedRows(items: supportRows) { row in
                    menuRow(row, showsValue: false)
                }
            }

            signOutButton
                .padding(.top, 16)

            Text("Spark 4.2.1")
                .font(SKFont.regular(11.5))
                .foregroundStyle(SK.ink4)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
    }

    // MARK: - Rows

    private var protectionRows: [MenuRow] {
        [
            MenuRow(label: "Devices",
                    value: String(store.devices.count),
                    icon: Icons.device) { store.go(.parental) },
            MenuRow(label: "Filter lists",
                    value: "\(activeListCount) active",
                    icon: Icons.lists) { store.show(Self.filterListsDetail) },
            MenuRow(label: "Privacy & data",
                    icon: Icons.shield) { store.show(Self.privacyDetail) },
        ]
    }

    private var activeListCount: Int {
        let keys = ["easylist", "privacy", "extra", "listSocial", "listMalware",
                    "listCrypto", "listRegional", "listNewsletters", "listComments"]
        return keys.filter { store.isOn($0) }.count
    }

    private var supportRows: [MenuRow] {
        [
            MenuRow(label: "Help & support", icon: Icons.help) { store.show(Self.helpDetail) },
            MenuRow(label: "Send feedback", icon: Icons.feedback) { store.show(Self.feedbackDetail) },
        ]
    }

    private func menuRow(_ row: MenuRow, showsValue: Bool) -> some View {
        HStack(spacing: 13) {
            IconTile {
                StrokeIcon(path: row.icon)
            }
            Text(row.label)
                .font(SKFont.semibold(14.5))
                .tracking(-0.2)
                .foregroundStyle(SK.ink)
            Spacer(minLength: 8)
            if showsValue, !row.value.isEmpty {
                Text(row.value)
                    .font(SKFont.regular(13))
                    .foregroundStyle(SK.ink3)
            }
            Chevron(size: 13, color: SK.chevronStrong, lineWidth: 1.9)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: row.action)
    }

    // MARK: - Account

    private var accountCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x6A86DD), SK.accent],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 46)
                .overlay {
                    Text(initials)
                        .font(SKFont.bold(16))
                        .tracking(-0.3)
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(store.profileName)
                    .font(SKFont.bold(15.5))
                    .tracking(-0.3)
                    .foregroundStyle(SK.ink)
                Text("Account & profile")
                    .font(SKFont.regular(12.5))
                    .foregroundStyle(SK.ink3)
            }
            Spacer(minLength: 8)
            Chevron(size: 13, color: SK.chevronStrong, lineWidth: 1.9)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { store.show(accountDetail) }
    }

    private var initials: String {
        let parts = store.profileName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private var signOutButton: some View {
        Text("Sign out")
            .font(SKFont.semibold(14.5))
            .tracking(-0.2)
            .foregroundStyle(SK.danger)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(SK.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .softShadow()
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture {
                store.ask(ConfirmSpec(
                    title: "Sign out of Spark?",
                    body: "Blocking stays on, but you will need to sign in to change any settings.",
                    actionLabel: "Sign out",
                    then: .home
                ))
            }
    }

    // MARK: - Detail specs

    private var accountDetail: DetailSpec {
        DetailSpec(
            title: store.profileName,
            subtitle: store.profileEmail,
            note: "Signed in on \(store.devices.count) device\(store.devices.count == 1 ? "" : "s").",
            rows: [
                DetailRow(label: "Name", value: store.profileName, action: .form(Forms.editName)),
                DetailRow(label: "Email", value: store.profileEmail, action: .form(Forms.editEmail)),
                DetailRow(label: "Devices", value: String(store.devices.count), action: .tab(.parental)),
                DetailRow(label: "Password", value: "Change", action: .form(Forms.changePassword)),
            ]
        )
    }

    /// The full filter-list catalogue, also reachable from "Browse all".
    static let filterListsDetail = DetailSpec(
        title: "Filter lists",
        subtitle: "Everything Spark can match against",
        note: "More lists means tighter filtering and slightly slower page loads.",
        rows: [
            DetailRow(label: "Spark Essentials", subtitle: "1.2M rules · updated 2h ago", toggleKey: "easylist"),
            DetailRow(label: "Privacy & tracking", subtitle: "480k rules · updated today", toggleKey: "privacy"),
            DetailRow(label: "Annoyances extra", subtitle: "Newsletter and app nags", toggleKey: "extra"),
            DetailRow(label: "Social widgets", subtitle: "Share buttons and embeds", toggleKey: "listSocial"),
            DetailRow(label: "Malware domains", subtitle: "Known phishing and malware hosts", toggleKey: "listMalware"),
            DetailRow(label: "Crypto mining", subtitle: "In-page miners", toggleKey: "listCrypto"),
            DetailRow(label: "Regional lists", subtitle: "Non-English ad networks", toggleKey: "listRegional"),
            DetailRow(label: "Newsletter pop-ups", subtitle: "Email capture overlays", toggleKey: "listNewsletters"),
            DetailRow(label: "Comment sections", subtitle: "Third-party comment embeds", toggleKey: "listComments"),
        ]
    )

    private static let privacyDetail = DetailSpec(
        title: "Privacy & data",
        subtitle: "What Spark keeps and what it never sees",
        note: "Spark filters on device. Browsing history never leaves your phone.",
        rows: [
            DetailRow(label: "Share anonymous usage",
                      subtitle: "Helps tune filter lists",
                      toggleKey: "shareUsage"),
            DetailRow(label: "Weekly family report",
                      subtitle: "Emailed every Monday",
                      toggleKey: "weeklyReport"),
            DetailRow(label: "Data stored", value: "On device"),
            DetailRow(label: "Delete all data", isDanger: true,
                      action: .confirm(ConfirmSpec(
                          title: "Delete all Spark data?",
                          body: "Blocking counts, allowed sites and device limits are erased from this phone.",
                          actionLabel: "Delete data",
                          then: .deleteAllData
                      ))),
        ]
    )

    private static let helpDetail = DetailSpec(
        title: "Help & support",
        subtitle: "Answers and a way to reach us",
        note: "Average reply time: under 4 hours.",
        rows: [
            DetailRow(label: "Getting started", value: "6 articles",
                      action: .push(Articles.gettingStarted)),
            DetailRow(label: "Blocking not working", value: "4 articles",
                      action: .push(Articles.notWorking)),
            DetailRow(label: "Managing devices", value: "5 articles",
                      action: .push(Articles.managingDevices)),
            DetailRow(label: "Contact support", action: .form(Forms.contactSupport)),
        ]
    )

    private static let feedbackDetail = DetailSpec(
        title: "Send feedback",
        subtitle: "Tell us what to fix or build next",
        note: "Feedback goes straight to the Spark team.",
        rows: [
            DetailRow(label: "Report a site that slipped through",
                      action: .form(Forms.feedback("Site slipped through"))),
            DetailRow(label: "Report a site Spark broke",
                      action: .form(Forms.feedback("Site Spark broke"))),
            DetailRow(label: "Request a feature",
                      action: .form(Forms.feedback("Feature request"))),
        ]
    )
}
