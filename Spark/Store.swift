import SwiftUI
import Observation
import UIKit

/// Single source of truth for the app. Mirrors the state object in the Claude
/// Design source — one flat bag of switches, one bag of rule values — plus the
/// navigation stack, the modal stack and the lists the user can add to.
@Observable
@MainActor
final class Store {
    // Navigation
    var tab: Tab = .home
    var stack: [Route] = []

    // Modals
    var sheetOpen = false
    var picker: PickerSpec?
    var confirm: ConfirmSpec?
    var form: FormSpec?
    var formValues: [String: String] = [:]
    var toast: String?
    var toastStyle: ToastStyle = .success

    // Mutable content
    var devices: [Device] = Devices.seed
    var allowedSites: [SiteEntry] = SparkContent.allowedSeed
    var blockedSites: [SiteEntry] = []

    // Profile
    var profileName = "Timothy K."
    var profileEmail = "timothy@example.com"

    // Per-app blocking
    var apps: [String: Bool] = [
        "safari": true, "chrome": true, "youtube": true, "reddit": false,
    ]

    // Every toggle in the app, keyed the same way the design keyed them.
    var switches: [String: Bool] = [
        "master": true, "ads": true, "trackers": true, "popups": true, "cookies": false,
        "easylist": true, "privacy": true, "extra": false,
        "d1": true, "d2": true, "d3": false,
        "shareUsage": false, "weeklyReport": true,
        // Additional lists behind "Browse all"
        "listSocial": false, "listMalware": true, "listCrypto": true,
        "listRegional": false, "listNewsletters": false, "listComments": false,
    ]

    // Per-device rule values.
    var values: [String: String] = [
        "d1Limit": "3h", "d1Filter": "Strict", "d1Bed": "9:30 PM",
        "d2Limit": "1h 30m", "d2Filter": "Strict", "d2Bed": "8:00 PM",
        "d3Limit": "No limit", "d3Filter": "Moderate", "d3Bed": "Off",
    ]

    /// Drives the "Spark Connected" pill on Home — real reachability of the
    /// paired Spark Agent, not decorative.
    var sparkConnected = true

    // MARK: - Real device / network state

    var pairedBox: PairedBox?
    var networkState: NetworkState = .idle
    var discoveredBoxes: [DiscoveredBox] = []
    /// Non-nil (possibly empty, while loading) drives the device-claim sheet.
    var deviceClaimPicker: [AgentDevice]?
    /// Which device the searchable app-blocking picker is currently open for.
    var appPickerDeviceID: String?
    var blockingStats = BlockingStats(blockedToday: 1284, queriesToday: 0)
    /// Live usage minutes for real (MAC-keyed) devices, preferred over the
    /// static `Device.usedMinutes` seed when present.
    var liveUsageMinutes: [String: Int] = [:]
    /// AdGuard's catalog of recognized apps/services, fetched once and cached.
    var serviceCatalog: [ServiceCatalogEntry] = []
    /// Per-device blocked apps/sites, keyed by device id.
    var deviceBlocklists: [String: DeviceBlocklist] = [:]

    private let agent: SparkAgentClientProtocol
    private let bonjour = BonjourDiscovery()

    private var toastTask: Task<Void, Never>?
    private var nextDeviceNumber = 4

    private static let pairedBoxKey = "pairedBox"

    init() {
        // Mock is the exception, not the default: a normal launch (tapping the
        // app icon) carries no launch arguments at all, so defaulting to mock
        // there would ship an app that never talks to a real box. XCUITest is
        // the one context guaranteed to pass a flag on every launch (added in
        // the test harness's own `launch()` helper), so that's what mock keys
        // off — this also keeps every existing test deterministic regardless
        // of network conditions.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        agent = isUITesting ? MockSparkAgentClient() : LiveSparkAgentClient()

        if let box = Self.loadPairedBox(), let token = KeychainStore.loadToken() {
            pairedBox = box
            agent.configure(box: box, token: token)
            sparkConnected = true
        } else {
            sparkConnected = false
        }

        applyLaunchOverrides()

        if pairedBox != nil {
            Task { [weak self] in
                await self?.refreshStatus()
                await self?.refreshBlockingStats()
                // `devices` starts as the mock seed on every launch — without
                // this, a real claimed device silently disappears from the
                // list on relaunch (it's still claimed server-side, just
                // invisible here), and any control the user then touches
                // (a d1/d2/d3 seed row that happens to occupy its old slot)
                // silently no-ops instead of reaching the real device.
                await self?.refreshClaimedDevices()
            }
        }
    }

    // MARK: - Derived

    var masterOn: Bool { switches["master"] ?? false }

    var route: Route? { stack.last }

    var selectedDeviceID: String {
        if case .device(let id) = stack.last { return id }
        return devices.first?.id ?? "d1"
    }

    var selectedDevice: Device {
        devices.first { $0.id == selectedDeviceID } ?? devices.first
            ?? Device(id: "none", name: "", subtitle: "", usedMinutes: 0)
    }

    func isOn(_ key: String) -> Bool { switches[key] ?? false }

    func value(_ key: String) -> String { values[key] ?? "" }

    /// Real devices are keyed by MAC address (from the claim flow); the seed
    /// devices (`d1`/`d2`/`d3`) are not backed by anything a Spark Agent knows
    /// about, so they stay purely local/cosmetic exactly as before.
    private func isRealDevice(_ id: String) -> Bool { id.contains(":") }

    // MARK: - Mutations

    func toggle(_ key: String) {
        let newValue = !(switches[key] ?? false)
        withAnimation(.easeInOut(duration: 0.18)) {
            switches[key] = newValue
        }
        if isRealDevice(key) {
            Task { await self.syncDeviceEnabled(key, newValue) }
        }
    }

    private func syncDeviceEnabled(_ id: String, _ on: Bool) async {
        do {
            try await agent.setRules(mac: id, patch: ["enabled": on])
        } catch {
            withAnimation { switches[id] = !on }
            flashError("Couldn't update this device")
        }
    }

    func toggleApp(_ key: String) {
        withAnimation(.easeInOut(duration: 0.18)) {
            apps[key] = !(apps[key] ?? false)
        }
    }

    /// Separate from `toggle(_:)`: the master switch talks to AdGuard Home's
    /// global protection endpoint, not a per-device rules patch, and rolls
    /// back optimistically on failure rather than silently no-op'ing.
    func toggleMaster() async {
        let wasOn = switches["master"] ?? false
        withAnimation(.easeInOut(duration: 0.18)) { switches["master"] = !wasOn }
        do {
            try await agent.setProtection(!wasOn)
        } catch {
            withAnimation(.easeInOut(duration: 0.18)) { switches["master"] = wasOn }
            flashError("Couldn't reach your Spark box")
        }
    }

    func refreshStatus() async {
        guard let status = try? await agent.fetchStatus() else { return }
        withAnimation(.easeInOut(duration: 0.18)) { switches["master"] = status.protectionEnabled }
        sparkConnected = true
    }

    func refreshBlockingStats() async {
        guard let stats = try? await agent.fetchStats() else { return }
        blockingStats = BlockingStats(blockedToday: stats.blocked, queriesToday: stats.queries)
    }

    func go(_ tab: Tab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.tab = tab
            stack.removeAll()
            sheetOpen = false
        }
    }

    func push(_ route: Route) {
        withAnimation(.easeInOut(duration: 0.22)) {
            stack.append(route)
            sheetOpen = false
        }
    }

    func openDevice(_ id: String) { push(.device(id)) }

    func show(_ detail: DetailSpec) { push(.detail(detail)) }

    func back() {
        guard !stack.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            _ = stack.removeLast()
        }
    }

    func removeAllowed(_ domain: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            allowedSites.removeAll { $0.domain == domain }
        }
        flashToast("\(domain) removed")
    }

    func removeBlocked(_ domain: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            blockedSites.removeAll { $0.domain == domain }
        }
        flashToast("\(domain) unblocked")
    }

    // MARK: - Picker

    func openPicker(valueKey: String, title: String, options: [String]) {
        withAnimation(.easeOut(duration: 0.22)) {
            picker = PickerSpec(valueKey: valueKey, title: title, options: options)
        }
    }

    func pick(_ option: String) {
        guard let picker else { return }
        let key = picker.valueKey
        values[key] = option
        withAnimation(.easeIn(duration: 0.2)) { self.picker = nil }
        syncPickedRuleIfNeeded(key: key, option: option)
    }

    /// `values` keys are `"\(deviceID)Filter"` / `"\(deviceID)Bed"` /
    /// `"\(deviceID)Limit"` — for a real (MAC-keyed) device, also push the
    /// change to the paired Spark Agent. Seed devices (`d1`/`d2`/`d3`) fail
    /// the `isRealDevice` check and stay exactly as local as before.
    private func syncPickedRuleIfNeeded(key: String, option: String) {
        if key.hasSuffix("Filter") {
            let id = String(key.dropLast("Filter".count))
            guard isRealDevice(id) else { return }
            Task { await self.syncContentFilter(id, option) }
        } else if key.hasSuffix("Bed") {
            let id = String(key.dropLast("Bed".count))
            guard isRealDevice(id) else { return }
            Task { await self.syncBedtime(id, option) }
        } else if key.hasSuffix("Limit") {
            let id = String(key.dropLast("Limit".count))
            guard isRealDevice(id) else { return }
            Task { await self.syncDailyLimit(id, option) }
        }
    }

    private func syncContentFilter(_ id: String, _ label: String) async {
        do {
            try await agent.setRules(mac: id, patch: ["content_filter": label.lowercased()])
        } catch {
            flashError("Couldn't update the content filter")
        }
    }

    private func syncBedtime(_ id: String, _ label: String) async {
        let value: Any
        if label == "Off" {
            value = NSNull()
        } else {
            value = ["enabled": true, "start": bedtimeStart(from: label), "wake": "07:00"]
        }
        do {
            try await agent.setRules(mac: id, patch: ["bedtime": value])
        } catch {
            flashError("Couldn't update bedtime")
        }
    }

    private func syncDailyLimit(_ id: String, _ label: String) async {
        let mins = minutes(from: label)
        let value: Any = mins.map { $0 as Any } ?? (NSNull() as Any)
        do {
            try await agent.setRules(mac: id, patch: ["daily_limit_minutes": value])
        } catch {
            flashError("Couldn't update the daily limit")
        }
    }

    /// "9:30 PM" -> "21:30". Falls back to a reasonable default rather than
    /// crashing if the label ever doesn't parse.
    private func bedtimeStart(from label: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        guard let date = formatter.date(from: label) else { return "21:00" }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 21, comps.minute ?? 0)
    }

    func closePicker() {
        withAnimation(.easeIn(duration: 0.2)) { picker = nil }
    }

    // MARK: - Sheet

    func setSheet(_ open: Bool) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { sheetOpen = open }
    }

    // MARK: - Confirm

    func ask(_ spec: ConfirmSpec) {
        withAnimation(.easeOut(duration: 0.2)) { confirm = spec }
    }

    func closeConfirm() {
        withAnimation(.easeIn(duration: 0.18)) { confirm = nil }
    }

    func resolveConfirm() {
        let spec = confirm
        var message: String?
        withAnimation(.easeInOut(duration: 0.22)) {
            confirm = nil
            stack.removeAll()
            switch spec?.then {
            case .home:
                tab = .home
            case .removeDevice:
                if let id = spec?.deviceID {
                    let name = devices.first { $0.id == id }?.name
                    devices.removeAll { $0.id == id }
                    liveUsageMinutes.removeValue(forKey: id)
                    deviceBlocklists.removeValue(forKey: id)
                    if isRealDevice(id) {
                        Task { try? await self.agent.deleteDevice(mac: id) }
                    }
                    message = name.map { "\($0) removed" }
                }
            case .deleteAllData:
                devices = Devices.seed
                allowedSites = SparkContent.allowedSeed
                blockedSites = []
                message = "All Spark data deleted"
            case .unpairBox:
                let boxName = pairedBox?.boxName
                unpair()
                message = boxName.map { "Forgot \($0)" }
            case .back, .none:
                break
            }
        }
        if let message { flashToast(message) }
    }

    // MARK: - Pairing

    func startPairingDiscovery() {
        discoveredBoxes = []
        bonjour.start { [weak self] box in
            guard let self else { return }
            if !self.discoveredBoxes.contains(box) {
                self.discoveredBoxes.append(box)
            }
        }
    }

    func stopPairingDiscovery() {
        bonjour.stop()
    }

    func pair(to box: DiscoveredBox) async {
        networkState = .loading
        do {
            let (token, boxName) = try await agent.pair(
                host: box.host, port: box.port, clientName: UIDevice.current.name
            )
            let paired = PairedBox(boxName: boxName, host: box.host, port: box.port)
            pairedBox = paired
            KeychainStore.saveToken(token)
            Self.savePairedBox(paired)
            agent.configure(box: paired, token: token)
            sparkConnected = true
            networkState = .idle
            back()
            flashToast("Paired with \(boxName)")
            await refreshStatus()
            await refreshBlockingStats()
        } catch {
            networkState = .idle
            flashError((error as? SparkAgentError)?.errorDescription ?? "Couldn't pair with that box")
        }
    }

    func unpair() {
        let previous = pairedBox
        pairedBox = nil
        sparkConnected = false
        KeychainStore.deleteToken()
        Self.clearPairedBox()
        back()
        if previous != nil {
            Task { await self.agent.unpair() }
        }
    }

    private static func loadPairedBox() -> PairedBox? {
        guard let data = UserDefaults.standard.data(forKey: pairedBoxKey) else { return nil }
        return try? JSONDecoder().decode(PairedBox.self, from: data)
    }

    private static func savePairedBox(_ box: PairedBox) {
        if let data = try? JSONEncoder().encode(box) {
            UserDefaults.standard.set(data, forKey: pairedBoxKey)
        }
    }

    private static func clearPairedBox() {
        UserDefaults.standard.removeObject(forKey: pairedBoxKey)
    }

    // MARK: - Device claiming

    /// Re-adopts devices Spark already claimed in an earlier session/relaunch
    /// (the Agent's `state.json` remembers them even though this in-memory
    /// list forgot). Idempotent — safe to call repeatedly; only ever adds
    /// missing entries, never touches ones already present locally.
    func refreshClaimedDevices() async {
        guard let all = try? await agent.fetchDevices() else { return }
        let existingIDs = Set(devices.map { $0.id })
        let alreadyClaimed = all.filter { $0.isAlreadyClaimed && !existingIDs.contains($0.mac) }
        guard !alreadyClaimed.isEmpty else { return }
        for agentDevice in alreadyClaimed {
            let name = agentDevice.name.isEmpty ? "New device" : agentDevice.name
            devices.append(Device(
                id: agentDevice.mac, name: name,
                subtitle: agentDevice.online ? "Online" : "Offline",
                usedMinutes: 0
            ))
            if switches[agentDevice.mac] == nil { switches[agentDevice.mac] = true }
            if values[agentDevice.mac + "Limit"] == nil { values[agentDevice.mac + "Limit"] = "No limit" }
            if values[agentDevice.mac + "Filter"] == nil { values[agentDevice.mac + "Filter"] = "Off" }
            if values[agentDevice.mac + "Bed"] == nil { values[agentDevice.mac + "Bed"] = "Off" }
        }
    }

    func startDeviceClaim() async {
        deviceClaimPicker = []
        networkState = .loading
        do {
            let all = try await agent.fetchDevices()
            let claimedMacs = Set(devices.map { $0.id })
            let unclaimed = all.filter { !claimedMacs.contains($0.mac) }
            networkState = .idle
            if unclaimed.isEmpty {
                deviceClaimPicker = nil
                flashError("No new devices found on your network")
            } else {
                deviceClaimPicker = unclaimed
            }
        } catch {
            networkState = .idle
            deviceClaimPicker = nil
            flashError("Couldn't reach your Spark box")
        }
    }

    func closeDeviceClaim() {
        deviceClaimPicker = nil
    }

    func claimDevice(_ agentDevice: AgentDevice) async {
        let name = agentDevice.name.isEmpty ? "New device" : agentDevice.name
        do {
            try await agent.claimDevice(mac: agentDevice.mac, name: name)
            withAnimation(.easeInOut(duration: 0.2)) {
                devices.append(Device(
                    id: agentDevice.mac, name: name,
                    subtitle: agentDevice.online ? "Just added · Online" : "Just added",
                    usedMinutes: 0
                ))
                switches[agentDevice.mac] = true
                values[agentDevice.mac + "Limit"] = "No limit"
                values[agentDevice.mac + "Filter"] = "Off"
                values[agentDevice.mac + "Bed"] = "Off"
            }
            deviceClaimPicker = nil
            flashToast("\(name) added")
        } catch {
            flashError("Couldn't add that device")
        }
    }

    func refreshDeviceUsage(_ id: String) async {
        guard isRealDevice(id) else { return }
        guard let usage = try? await agent.fetchUsage(mac: id) else { return }
        liveUsageMinutes[id] = Int(usage.usedMinutesToday.rounded())
    }

    // MARK: - Per-device app/site blocking

    func loadServiceCatalogIfNeeded() async {
        guard serviceCatalog.isEmpty else { return }
        if let list = try? await agent.fetchServiceCatalog() {
            serviceCatalog = list
        }
    }

    func loadDeviceBlocklist(_ id: String) async {
        guard isRealDevice(id) else { return }
        if let bl = try? await agent.fetchBlocklist(mac: id) {
            deviceBlocklists[id] = bl
        }
    }

    func openAppPicker(for deviceID: String) {
        appPickerDeviceID = deviceID
        Task { await self.loadServiceCatalogIfNeeded() }
    }

    func closeAppPicker() {
        appPickerDeviceID = nil
    }

    func isAppBlocked(_ deviceID: String, _ appID: String) -> Bool {
        deviceBlocklists[deviceID]?.apps.contains(appID) ?? false
    }

    func toggleBlockedApp(_ deviceID: String, _ appID: String) {
        var bl = deviceBlocklists[deviceID] ?? DeviceBlocklist(apps: [], sites: [])
        withAnimation(.easeInOut(duration: 0.18)) {
            if bl.apps.contains(appID) {
                bl.apps.removeAll { $0 == appID }
            } else {
                bl.apps.append(appID)
            }
            deviceBlocklists[deviceID] = bl
        }
        guard isRealDevice(deviceID) else { return }
        let apps = bl.apps
        Task {
            do {
                try await self.agent.setBlocklist(mac: deviceID, apps: apps, sites: nil)
            } catch {
                self.flashError("Couldn't update blocked apps")
            }
        }
    }

    func removeBlockedSite(_ deviceID: String, _ domain: String) {
        var bl = deviceBlocklists[deviceID] ?? DeviceBlocklist(apps: [], sites: [])
        withAnimation(.easeInOut(duration: 0.2)) {
            bl.sites.removeAll { $0 == domain }
            deviceBlocklists[deviceID] = bl
        }
        guard isRealDevice(deviceID) else { return }
        let sites = bl.sites
        Task {
            do {
                try await self.agent.setBlocklist(mac: deviceID, apps: nil, sites: sites)
            } catch {
                self.flashError("Couldn't update blocked sites")
            }
        }
    }

    // MARK: - Forms

    func openForm(_ spec: FormSpec) {
        formValues = [:]
        // Profile edits start from the current value rather than blank.
        switch spec.kind {
        case .editProfile(let key):
            formValues[spec.fields.first?.id ?? ""] = key == "name" ? profileName : profileEmail
        case .renameDevice(let id):
            formValues[spec.fields.first?.id ?? ""] = devices.first { $0.id == id }?.name ?? ""
        default:
            break
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            form = spec
            sheetOpen = false
        }
    }

    func closeForm() {
        withAnimation(.easeIn(duration: 0.2)) { form = nil }
    }

    func formValue(_ key: String) -> String { formValues[key] ?? "" }

    func setFormValue(_ key: String, _ value: String) { formValues[key] = value }

    /// True when every required field has content — drives the primary button.
    var formIsValid: Bool {
        guard let form else { return false }
        return form.fields.allSatisfy { field in
            !field.required || !formValue(field.id).trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    func submitForm() {
        guard let form, formIsValid else { return }
        var message = ""

        switch form.kind {
        case .blockSite:
            let domain = cleanDomain(formValue("domain"))
            blockedSites.removeAll { $0.domain == domain }
            blockedSites.insert(SiteEntry(domain: domain, subtitle: "Blocked everywhere · added by you"), at: 0)
            message = "\(domain) blocked"

        case .allowSite:
            let domain = cleanDomain(formValue("domain"))
            allowedSites.removeAll { $0.domain == domain }
            allowedSites.insert(SiteEntry(domain: domain, subtitle: "Ads allowed · added by you"), at: 0)
            message = "\(domain) allowed"

        case .addBlockedSite(let deviceID):
            let domain = cleanDomain(formValue("domain"))
            var bl = deviceBlocklists[deviceID] ?? DeviceBlocklist(apps: [], sites: [])
            if !bl.sites.contains(domain) {
                bl.sites.append(domain)
                deviceBlocklists[deviceID] = bl
                if isRealDevice(deviceID) {
                    let sites = bl.sites
                    Task {
                        do {
                            try await self.agent.setBlocklist(mac: deviceID, apps: nil, sites: sites)
                        } catch {
                            self.flashError("Couldn't update blocked sites")
                        }
                    }
                }
            }
            message = "\(domain) blocked on this device"

        case .renameDevice(let id):
            let name = formValue("name").trimmingCharacters(in: .whitespaces)
            if let index = devices.firstIndex(where: { $0.id == id }) {
                devices[index].name = name
            }
            message = "Renamed to \(name)"

        case .contactSupport:
            message = "Message sent to support"

        case .sendFeedback:
            message = "Thanks — feedback sent"

        case .editProfile(let key):
            let value = formValue(key).trimmingCharacters(in: .whitespaces)
            if key == "name" { profileName = value } else { profileEmail = value }
            message = key == "name" ? "Name updated" : "Email updated"

        case .changePassword:
            message = "Password updated"
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            self.form = nil
        }
        flashToast(message)
    }

    /// Trims what people actually type — a pasted URL, a stray `www.`.
    private func cleanDomain(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where s.hasPrefix(prefix) {
            s.removeFirst(prefix.count)
        }
        if s.hasPrefix("www.") { s.removeFirst(4) }
        if let slash = s.firstIndex(of: "/") { s = String(s[s.startIndex..<slash]) }
        return s.isEmpty ? raw : s
    }

    // MARK: - Toast

    func flashToast(_ text: String) {
        toastTask?.cancel()
        toastStyle = .success
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { toast = text }
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { self?.toast = nil }
        }
    }

    func flashError(_ text: String) {
        toastTask?.cancel()
        toastStyle = .error
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { toast = text }
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(2400))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                self?.toast = nil
                self?.toastStyle = .success
            }
        }
    }

    // MARK: - Device detail derivations

    /// Usage never renders past the limit — matches the design's `min(used, limit)`.
    /// Prefers live-fetched usage for a real device when available.
    func usage(for device: Device) -> (label: String, caption: String, fraction: Double) {
        let limitLabel = value(device.id + "Limit")
        let usedMinutes = liveUsageMinutes[device.id] ?? device.usedMinutes
        guard let limit = minutes(from: limitLabel), limit > 0 else {
            return (label(fromMinutes: usedMinutes) + " used", "No daily limit set", 0.18)
        }
        let used = min(usedMinutes, limit)
        let atLimit = usedMinutes >= limit
        return (
            label(fromMinutes: used) + " used",
            atLimit ? "Limit reached" : "of \(limitLabel) limit",
            min(1, Double(used) / Double(limit))
        )
    }

    // MARK: - Launch overrides

    /// The design exposes `activeTab`, `blockingOn` and `sparkConnected` as
    /// editable props. Mirroring them as launch arguments keeps the same entry
    /// points for previews, screenshots and UI tests.
    private func applyLaunchOverrides() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "activeTab"), let t = Tab(rawValue: raw) {
            tab = t
        }
        if defaults.object(forKey: "blockingOn") != nil {
            switches["master"] = defaults.bool(forKey: "blockingOn")
        }
        if defaults.object(forKey: "sparkConnected") != nil {
            sparkConnected = defaults.bool(forKey: "sparkConnected")
        }
        #if DEBUG
        // Screenshot hooks for the overlays, which have no other entry point
        // from a cold launch.
        switch defaults.string(forKey: "openOverlay") {
        case "sheet":
            sheetOpen = true
        case "device":
            stack = [.device(defaults.string(forKey: "deviceID") ?? "d1")]
        case "picker":
            let id = defaults.string(forKey: "deviceID") ?? "d1"
            stack = [.device(id)]
            picker = PickerSpec(valueKey: id + "Limit", title: "Daily screen time", options: RuleOptions.limit)
        case "confirm":
            let id = defaults.string(forKey: "deviceID") ?? "d1"
            stack = [.device(id)]
            confirm = ConfirmSpec(
                title: "Remove \(devices.first { $0.id == id }?.name ?? "device")?",
                body: "Spark stops filtering on this device and its limits are deleted.",
                actionLabel: "Remove device",
                then: .removeDevice,
                deviceID: id
            )
        case "form":
            switch defaults.string(forKey: "formName") {
            case "contactSupport": form = Forms.contactSupport
            case "allowSite": form = Forms.allowSite
            default: form = Forms.blockSite
            }
        case "toast":
            toast = "Contact support"
        default:
            break
        }
        #endif
    }
}
