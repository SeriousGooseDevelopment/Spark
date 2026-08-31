import Foundation

// MARK: - Navigation

enum Tab: String, CaseIterable, Hashable {
    case home = "Home"
    case blocking = "Blocking"
    case parental = "Parental"
    case menu = "Menu"
}

/// One screen pushed over the tab content. The tab bar stays above the stack,
/// which can nest — Help & support → a topic → a single article.
enum Route: Hashable, Identifiable {
    case device(String)
    case detail(DetailSpec)
    case pairing

    var id: String {
        switch self {
        case .device(let id): return "device-\(id)"
        case .detail(let spec): return "detail-\(spec.id)"
        case .pairing: return "pairing"
        }
    }
}

// MARK: - Devices

struct Device: Identifiable, Hashable {
    let id: String
    var name: String
    var subtitle: String
    /// Minutes of screen time already used today.
    var usedMinutes: Int
}

enum Devices {
    /// Seed list. The store owns a mutable copy so devices can be added and removed.
    static let seed: [Device] = [
        Device(id: "d1", name: "Tim's iPhone", subtitle: "iOS 26 · In use now", usedMinutes: 105),
        Device(id: "d2", name: "Living room iPad", subtitle: "Shared · Last used 1h ago", usedMinutes: 65),
        Device(id: "d3", name: "Family MacBook", subtitle: "macOS · Offline", usedMinutes: 12),
    ]

    static let kinds = ["iPhone", "iPad", "Mac", "Apple TV", "Other"]
}

/// Picker option sets, keyed by the kind of rule being edited.
enum RuleOptions {
    static let limit = ["30m", "1h", "1h 30m", "2h", "3h", "No limit"]
    static let filter = ["Strict", "Moderate", "Off"]
    static let bedtime = ["8:00 PM", "8:30 PM", "9:00 PM", "9:30 PM", "10:00 PM", "Off"]
}

/// Parses a rule label like `1h 30m` into minutes. `No limit` / `Off` mean "unbounded".
func minutes(from label: String) -> Int? {
    guard label != "No limit", label != "Off", !label.isEmpty else { return nil }
    var total = 0
    if let r = label.range(of: #"(\d+)\s*h"#, options: .regularExpression),
       let h = Int(label[r].filter(\.isNumber)) {
        total += h * 60
    }
    if let r = label.range(of: #"(\d+)\s*m"#, options: .regularExpression),
       let m = Int(label[r].filter(\.isNumber)) {
        total += m
    }
    return total
}

func label(fromMinutes total: Int) -> String {
    let h = total / 60
    let m = total % 60
    if h == 0 { return "\(m)m" }
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

// MARK: - Networking / real-device state

enum NetworkState: Equatable {
    case idle
    case loading
    case error(String)
}

enum ToastStyle {
    case success
    case error
}

/// A device seen live on the network via the paired Spark Agent, not yet
/// claimed for parental controls.
struct AgentDevice: Identifiable, Hashable {
    var id: String { mac }
    let mac: String
    let ip: String
    let name: String
    let online: Bool
    /// "agh_client" means Spark has already claimed this device (it's in the
    /// Agent's own state, not just seen on the network) — as opposed to
    /// "agh_auto"/"arp_only" for a device merely spotted via ARP that hasn't
    /// been claimed yet. Distinguishes "already ours" from "available to add"
    /// in the claim sheet, and lets a relaunch re-adopt already-claimed
    /// real devices instead of only ever seeing them as claimable strangers.
    var source: String = "arp_only"
    var isAlreadyClaimed: Bool { source == "agh_client" }
}

struct BlockingStats: Equatable {
    var blockedToday: Int
    var queriesToday: Int
}

// MARK: - Row actions

/// What a detail row does when tapped. `indirect` because pushing another
/// detail screen nests a `DetailSpec` inside the row that opens it.
indirect enum RowAction: Hashable {
    /// Read-only row — no chevron, no tap.
    case none
    case push(DetailSpec)
    case form(FormSpec)
    case confirm(ConfirmSpec)
    case tab(Tab)

    var isTappable: Bool {
        if case .none = self { return false }
        return true
    }
}

// MARK: - Generic detail screen

/// One row on a pushed detail screen: a toggle, a read-only value, or an action.
struct DetailRow: Identifiable, Hashable {
    let id = UUID()
    var label: String
    var subtitle: String?
    var value: String?
    /// Backing key in `Store.switches` — makes this a toggle row.
    var toggleKey: String?
    var isDanger: Bool = false
    var action: RowAction = .none

    var isToggle: Bool { toggleKey != nil }
    var isValue: Bool { toggleKey == nil && !action.isTappable }
    var isTappable: Bool { toggleKey == nil && action.isTappable }
}

struct DetailSpec: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var subtitle: String
    var note: String
    var rows: [DetailRow]
    /// Long-form body shown instead of rows — used for help articles.
    var body: String?
}

// MARK: - Modals

struct PickerSpec: Identifiable, Hashable {
    let id = UUID()
    /// Key into `Store.values`.
    var valueKey: String
    var title: String
    var options: [String]
}

struct ConfirmSpec: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var body: String
    var actionLabel: String
    var then: Outcome
    var deviceID: String?

    enum Outcome: Hashable {
        /// Dismiss back to the tab, leaving everything else alone.
        case back
        /// Dismiss and return to the Home tab.
        case home
        /// Dismiss and drop `deviceID` from the device list.
        case removeDevice
        /// Dismiss and clear every list the user has added to.
        case deleteAllData
        /// Dismiss and forget the paired Spark box.
        case unpairBox
    }
}

// MARK: - Forms

struct FormField: Identifiable, Hashable {
    /// Key into `Store.formValues`.
    let id: String
    var label: String
    var placeholder: String
    var kind: Kind = .text
    var options: [String] = []
    var required: Bool = true

    enum Kind: Hashable {
        case text
        case domain
        case email
        case password
        case multiline
        /// Rendered as a segmented row of `options` rather than a text field.
        case choice
    }
}

/// What submitting a form does. Kept as data rather than a closure so the
/// store owns every mutation in one place.
enum FormKind: Hashable {
    case blockSite
    case allowSite
    case addBlockedSite(String)
    case renameDevice(String)
    case contactSupport
    case sendFeedback(String)
    case editProfile(String)
    case changePassword
}

struct FormSpec: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var subtitle: String
    var fields: [FormField]
    var primary: String
    var kind: FormKind
}

// MARK: - Site lists

struct SiteEntry: Identifiable, Hashable {
    var id: String { domain }
    let domain: String
    var subtitle: String
}

struct SiteStat: Identifiable, Hashable {
    var id: String { site }
    let site: String
    let count: String
    /// Bar width as a fraction of the row.
    let fraction: Double
}

enum SparkContent {
    static let allowedSeed: [SiteEntry] = [
        SiteEntry(domain: "localnews.co", subtitle: "Ads allowed · added by you"),
        SiteEntry(domain: "school-portal.org", subtitle: "Ads allowed · added 3 days ago"),
    ]

    static let blockedBySite: [SiteStat] = [
        SiteStat(site: "dailyledger.com", count: "412", fraction: 1.00),
        SiteStat(site: "sportsfeed.io", count: "268", fraction: 0.65),
        SiteStat(site: "recipebox.net", count: "196", fraction: 0.48),
        SiteStat(site: "forumhub.com", count: "134", fraction: 0.33),
    ]
}
